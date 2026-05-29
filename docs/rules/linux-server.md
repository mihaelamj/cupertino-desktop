# Linux-server Swift

Operational rules for Tiledown code that runs on Linux in production: HTTP client, logging, database, crypto, signals, resources, POSIX interop, file I/O, and Docker CI.

Load on demand. Triggers: Linux, server, Vapor, Hummingbird, AsyncHTTPClient, swift-log, swift-crypto, FluentSQLite, FluentPostgres, NIO, SIGTERM, graceful shutdown, Docker, `swift:6.0-jammy`, `swift:6.0-noble`, Bundle.module, FoundationNetworking on a server, isatty, BoringSSL.

If your target runs on Linux in production (server, CLI binary, container workload), this file is the operational rule. The higher-level topology rule and the `#if canImport(...)` patterns live in `docs/rules/cross-platform.md`; this file is the server-specific operational layer.

## When this rule applies

- Building a Vapor / Hummingbird / NIO server that ships to Linux (Docker, ECS, Kubernetes).
- Building a Swift CLI that supports Linux installation (Homebrew on macOS, package manager or `swift build` on Linux).
- Building a server that ships cross-platform.
- Any repo with a Linux-buildable product in its Package.swift (Topology 2 or 3 from `cross-platform.md`).

If the answer is "Apple-only iOS/macOS app, no Linux," skip this file; load `cross-platform.md` for the Apple-cross-platform patterns instead.

Note: the TileKit engine targets macOS and Linux. Both support subprocess and shell-out, so the engine may spawn subprocesses. As a design preference, keep server-only concerns (this file's HTTP/database/signal patterns) in dedicated CLI/server targets rather than the core, so the core stays focused; this is an organizational choice, not a platform limitation.

## 1. HTTP: AsyncHTTPClient, not URLSession

The canonical HTTP client on Linux server code is `AsyncHTTPClient` (swift-server). Use it on every platform for cross-platform parity, not just Linux.

```swift
import AsyncHTTPClient
import NIOHTTP1

let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
let request = HTTPClientRequest(url: "https://example.com/api")
let response = try await httpClient.execute(request, timeout: .seconds(30))
let body = try await response.body.collect(upTo: 1024 * 1024)
```

**Why not URLSession on Linux:** `FoundationNetworking`'s URLSession on Linux lacks `URLSessionWebSocketTask`, `URLSessionStreamTask`, and PAC (proxy auto-configuration). For any feature beyond plain `data(from:)`, you will hit gaps.

**Why use AsyncHTTPClient on Apple too:** a single HTTP client across all platforms eliminates the entire `#if canImport(FoundationNetworking)` class of bug. The cost is one dependency. You can tune one `HTTPClient` config (HTTP/1.1 only, short idle timeout, POSIX sockets) and run the same code on macOS and Linux.

**TLS:** AsyncHTTPClient ships bundled BoringSSL on Linux; on Apple it uses Security.framework transparently. No source-level branching needed.

If you must use URLSession (existing library code, an Apple-specific feature), see `cross-platform.md` Pattern 10 for the `canImport(FoundationNetworking)` form.

**URLSession lifetime on Linux (FoundationNetworking):** `URLSession.deinit` asserts that the session was invalidated before release. On Apple platforms this is advisory; on Linux it crashes with "Object deallocated with non-zero retain count" at process exit. Always invalidate before the session goes out of scope:

```swift
// Wrong: session deallocated without invalidation, Linux crash
let session = URLSession(configuration: .ephemeral)
// ... use session ...
// session goes out of scope here → crash

// Correct option 1: final class with deinit (preferred, automatic for all callers)
public final class TileDownloader: @unchecked Sendable {
    private let session: URLSession
    init() { session = URLSession(configuration: .ephemeral) }
    deinit { session.invalidateAndCancel() }
}

// Correct option 2: explicit invalidation at call site
defer { session.invalidateAndCancel() }
```

Use `invalidateAndCancel()` rather than `finishTasksAndInvalidate()` when all tasks are already done. `invalidateAndCancel` sets `invalidated = true` synchronously, whereas `finishTasksAndInvalidate` does so async on the work queue and may not run before process exit. Sessions created with a delegate (e.g., for TLS handling) are especially prone to this: the session retains the delegate, and the retain cycle is only broken on invalidation.

## 2. Logging: swift-log on the server, `canImport(os)` only for local dev

Two-tier strategy:

**Server tier (Vapor / Hummingbird / NIO target):** use `swift-log` (the `Logging` package) exclusively. Bootstrap once at startup:

```swift
import Logging

LoggingSystem.bootstrap { label in
    var handler = StreamLogHandler.standardError(label: label)
    handler.logLevel = .info
    return handler
}

let logger = Logger(label: "com.example.tiledown")
logger.info("server starting")
```

In production, redirect stderr to journald / Docker logs / your hosting platform's log sink.

**App tier (iOS / macOS UI):** wrap `os.log` with a `canImport(os)` conditional and a print fallback:

```swift
#if canImport(os)
import os.log

public struct TileLogger {
    private let logger: Logger
    public init(subsystem: String, category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
    }
    public func info(_ message: String) { logger.info("\(message, privacy: .public)") }
    public func error(_ message: String) { logger.error("\(message, privacy: .public)") }
}
#else
public struct TileLogger {
    public init(subsystem: String, category: String) {}
    public func info(_ message: String)  { print("[INFO] \(message)") }
    public func error(_ message: String) { print("[ERROR] \(message)") }
}
#endif
```

The Apple side uses unified logging (Console, Instruments). The Linux side uses print. Same call site, different sink.

**Do not mix the two in the same file.** `Logger` (swift-log) and `Logger` (os.log) are different types with the same name. Trying to use both in one source file requires fully qualified names (`Logging.Logger` vs `os.Logger`) and is brittle. Pick one per target.

Reference: SSWG `swift-log` is the standard for the server tier.

## 3. Database: Fluent on Linux, avoid CoreData

CoreData is Apple-only; do not reach for it on the server. Options on Linux:

- **Vapor + Fluent + FluentSQLiteDriver** (local development) / **FluentPostgresDriver** (production), the dominant SSWG stack.
- **GRDB**, a cross-platform SQLite wrapper, single binary, no actor abstractions.
- **swift-sqlite** (the raw `sqlite3` C module imported via Swift), the lowest level, lowest overhead. A good fit for FTS5 search indexes.

**CloudKit, iCloud Drive, NSPersistentCloudKitContainer:** Apple-only. For Linux backends that need sync, build it explicitly over your chosen database driver.

## 4. Cryptography: swift-crypto cross-platform, CryptoKit Apple-only

The standard conditional:

```swift
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
```

This imports correctly on both platforms. But the APIs are NOT fully source-compatible. Real gotchas:

- **`SHA256.hash` vs `SHA256.digest`**: CryptoKit exposes `Digest` types differently. The hash methods return `Digest` on CryptoKit and `Digest` on Crypto, but their `description`, `Sequence` conformance, and bytewise iteration can differ at the protocol level. Test both sides.
- **`SecureEnclave`** does not exist in swift-crypto. Hardware-backed keys are Apple-only.
- **`SymmetricKey(data:)`** is identical on both. `ChaChaPoly`, `AES.GCM`, `HKDF`, `Curve25519` are all source-compatible.
- **`P256.Signing.PrivateKey.publicKey.derRepresentation`** is identical.

When in doubt: write the code against `Crypto` first (smaller surface, cross-platform), only reach for `CryptoKit`-specific APIs (SecureEnclave, biometric-backed keys) at Apple-only call sites with explicit `#if canImport(CryptoKit)` guards.

## 5. Graceful shutdown: SIGTERM grace then SIGKILL

Server containers receive SIGTERM on shutdown (Docker stop, Kubernetes pod termination, systemd stop). The correct response: stop accepting new work, drain in-flight requests, exit cleanly. Vapor and Hummingbird handle the basic SIGTERM hook automatically; your server's `application.run()` returns when SIGTERM arrives.

For multi-process supervisors (a parent that forks server children), the reaper pattern:

```swift
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

func reapChild(pid: pid_t, graceSeconds: Double = 2.0) {
    _ = kill(pid, SIGTERM)
    let deadline = Date().addingTimeInterval(graceSeconds)
    while Date() < deadline {
        var status: Int32 = 0
        if waitpid(pid, &status, WNOHANG) == pid { return }   // exited cleanly
        Thread.sleep(forTimeInterval: 0.1)
    }
    _ = kill(pid, SIGKILL)
    _ = waitpid(pid, nil, 0)
}
```

POSIX signal semantics are identical on Linux and Darwin (sigaction, signal handlers, realtime signals). The wrapper is for the `Darwin` vs `Glibc` import only.

**Gotcha:** `proc_pidpath()` is Darwin-only. To resolve a Linux child's binary path, read `/proc/$pid/exe` as a symlink. Do not assume `proc_pidpath` works cross-platform.

**For Vapor servers specifically:** Vapor calls `application.shutdown()` on SIGTERM, which drains the event loop group. Do not reinvent. For Hummingbird, the equivalent is `application.shutdownGracefully()`.

## 6. Resources: compile to Swift, do not rely on `Bundle.module`

`Bundle.module` is Apple-only as a fully reliable API. On Linux SPM, `Bundle.module` either does not exist or returns paths that do not match expectations. On macOS with Homebrew installs, the binary symlink trap breaks `Bundle.module` lookups even on Apple. Both failure modes have the same fix: compile resources as Swift code.

The pattern (in a `Resources` target):

```swift
// Embedded/Static.swift (generated)
extension Embedded {
    static let initialSeedJSON: String = """
    {
      "key": "value",
      ...
    }
    """
}
```

A build-time generator script reads the resource file, escapes it as a Swift string literal, and writes the `.swift` file. At runtime, no bundle lookup, no FS access, no symlink resolution. Works identically on every platform.

When this pays off:

- Resource is small (< 1 MB total per file works fine in a string literal).
- Resource is read-only at runtime.
- Resource is needed at startup (no lazy disk access).
- You are shipping a binary to multiple package managers (Homebrew, apt, MSI) and do not want to debug each one's resource-path semantics.

When to NOT use:

- Large binary assets (images, sound, large CSV). Use SPM's `resources: [.process("...")]` and read at runtime; accept the platform-specific resource lookup.
- Resources that change per-installation (user data, downloaded content).

## 7. POSIX C interop: Darwin / Glibc / Musl

For raw POSIX calls (read, write, ioctl, signal, kill, waitpid, dup2, pipe), the canonical conditional:

```swift
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif
```

Musl is reserved for Alpine Linux containers; most production deployments use glibc (Ubuntu, Debian, Amazon Linux 2, RHEL). Test on Musl only if your container base is Alpine.

**Modern alternative, `apple/swift-system`:**

```swift
import SystemPackage

let fd = try FileDescriptor.open("/path", .readOnly)
defer { try? fd.close() }
let bytesRead = try fd.read(into: buffer)
```

`swift-system` provides a unified Swift surface for POSIX file I/O, file paths, errno handling. Use it for new code instead of raw Darwin/Glibc imports. Reference: SYS-0008 (`CInterop.stat` back-deploy), SE-0063, SE-0208.

**When to reach for raw imports:** legacy code, operations not covered by `swift-system` (signal handlers, exec / posix_spawn, terminal ioctls).

## 8. FileHandle write API diverges

`FileHandle.write(_:)` has different signatures across platforms:

- macOS / iOS: `func write(_ data: Data)`, non-throwing, never actually fails
- Linux (swift-corelibs-foundation): `func write(contentsOf: Data) throws`, throws on error

Code that compiles on one platform may not compile on the other. The wrapper:

```swift
extension FileHandle {
    func write(contentsOf data: Data) throws {
        #if canImport(Darwin)
        write(data)
        #else
        try write(contentsOf: data)
        #endif
    }
}
```

Use this wrapper anywhere FileHandle writes are needed in cross-platform code. Apple platforms swallow errors silently (consistent with their non-throwing API); Linux propagates.

**Alternative:** switch to `swift-system`'s `FileDescriptor.write(_:)`, which has the same throwing signature on every platform.

## 9. Piped stdio detection: `isatty()`

When a CLI binary is piped (shell pipeline, log collector, host process), interactive prompts and TUI escape sequences must be suppressed. Standard POSIX check, works identically on Linux and Darwin:

```swift
import Foundation

let isPiped = isatty(STDOUT_FILENO) == 0

if isPiped {
    // protocol mode: structured output only
} else {
    // interactive mode: colours, prompts, redraws
}
```

Use this to disable terminal logging when the binary is invoked by another process rather than an interactive shell.

## 10. Test framework on cross-platform server code

XCTest works on Linux (auto-discovery since Swift 5.4; no `LinuxMain.swift` required). Swift Testing is platform-agnostic by design. For new tests in any Linux-buildable target, default to Swift Testing.

```swift
import Testing

@Test func serverHealthEndpointReturns200() async throws {
    let response = try await client.execute(.health)
    #expect(response.status == .ok)
}
```

Mixed XCTest / Swift Testing in the same target is fine; both runners coexist. See `concurrency.md` for the broader rule.

References: ST-0009, ST-0016, ST-0017, ST-0022 (Swift Testing parity across Apple, Linux, Windows).

## 11. CI for Linux-buildable server products

Every Linux-buildable product runs a Linux build on every PR. Minimum GitHub Actions job:

```yaml
linux-build:
  runs-on: ubuntu-latest
  container: swift:6.0-jammy
  steps:
    - uses: actions/checkout@v4
    - run: swift build -c release --product <your-linux-product>
```

For testing, add a parallel job that runs `swift test --filter <LinuxBuildableSuite>` against the Linux-buildable test suites.

**Docker image choice:**
- `swift:6.0-jammy`, Ubuntu 22.04 LTS, the default for most production deploys.
- `swift:6.0-noble`, Ubuntu 24.04 LTS, newer.
- `swift:6.0-jammy-slim`, runtime-only base for the production stage.
- `swift:6.0-bookworm`, Debian 12, for some legacy deploys.
- `swift:6.0-alpine`, Alpine + Musl, smallest image. Test Musl conditionals if you use this.

**Production deployment via Docker:**

```dockerfile
FROM swift:6.0-jammy as build
WORKDIR /src
COPY . .
RUN swift build -c release --product tiledownserver

FROM swift:6.0-jammy-slim
COPY --from=build /src/.build/release/tiledownserver /usr/local/bin/
EXPOSE 8080
CMD ["tiledownserver"]
```

Multi-stage builds keep the runtime image small. The Docker production path can catch catastrophic failures, but it is not a substitute for PR-time Linux CI; deploy-time discovery means broken builds reach main.

## 12. Manifest discipline (Topology 2: Apple clients + Linux server)

If your repo is the Apple-clients-plus-Linux-server split (`cross-platform.md` Topology 2), the manifest pattern from `cross-platform.md` Layer A applies:

```swift
let baseProducts: [Product] = [
    .singleTargetLibrary("TileKit"),
    .singleTargetLibrary("TileServer"),
    .executable(name: "tiledownserver", targets: ["TileServerApp"]),
    // ... unconditional, Linux-buildable
]

#if os(iOS) || os(macOS)
let appleOnlyProducts: [Product] = [
    .singleTargetLibrary("TileDownUI"),
    .singleTargetLibrary("TileDownComponents"),
    // ... Apple-only UI
]
#else
let appleOnlyProducts: [Product] = []
#endif

let products = baseProducts + appleOnlyProducts
```

Same shape for targets. Server-side products and targets stay unconditional. UI-side wraps in the conditional array.

Document the Linux-buildable surface in the repo's `README.md`: name the product (`tiledownserver`), name the build command (`swift build -c release --product tiledownserver`), name the supported Docker image. Otherwise new developers running plain `swift build` on Linux hit Apple-target compile errors.

## 13. Cross-references

- **`docs/rules/cross-platform.md`** is the higher-level topology rule and covers UI patterns + library patterns. This file is the server-specific operational layer; load both together for a server repo.
- **`concurrency.md`** is platform-agnostic; Sendable + async/await behave identically on Apple and Linux.

## 14. Authoritative references

- **SSWG packages:** `swift-server/async-http-client`, `apple/swift-log`, `apple/swift-crypto`, `apple/swift-system`, `apple/swift-nio`.
- **Vapor / Hummingbird:** their respective package docs.
- **System interop:** SE-0063, SE-0208 (System packages). SYS-0008 (`CInterop.stat` back-deploy).
- **Swift Testing platforms:** ST-0009, ST-0016, ST-0017, ST-0022.
- **swift-foundation architecture:** `swiftlang/swift-foundation` README for the three-tier model (Darwin / swift-foundation / swift-corelibs-foundation).

## Quick reference table

| Concern | Apple-only choice | Cross-platform / Linux server choice |
|---|---|---|
| HTTP client | URLSession | AsyncHTTPClient |
| Logging | `os.Logger` | swift-log (`Logging`) |
| Crypto | CryptoKit | swift-crypto (`Crypto`) |
| Database | CoreData | Fluent + SQLite/Postgres driver, GRDB, or raw `sqlite3` |
| C interop | `import Darwin` | `swift-system` preferred; `canImport(Darwin/Glibc/Musl)` for legacy |
| FileHandle write | `write(_:)` non-throwing | wrap with `canImport(Darwin)` (see § 8) |
| Resources | `Bundle.module` | compile to Swift code |
| Tests | XCTest or Swift Testing | Swift Testing (platform-agnostic) |
| Shutdown | OS handles UI lifecycle | SIGTERM grace + SIGKILL |
| CI | macOS only | macOS + Linux Docker on every PR |
| Production runtime | App Store / Mac App | Docker container (jammy-slim base) |
