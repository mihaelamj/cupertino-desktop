# Cross-platform Swift (Apple + Linux + Windows)

How to structure Tiledown's Swift so the same sources build and run on Apple platforms, Linux, and Windows without silent breakage.

Load on demand. Triggers: `canImport`, `Linux`, `FoundationNetworking`, `Darwin`, `Glibc`, `swift-system`, `swift-foundation`, cross-platform, manifest, `.when(platforms:)`, `os(Linux)`, `os(iOS)`, `os(macOS)`, `os(visionOS)`, `os(tvOS)`, Vapor, AsyncHTTPClient, Hummingbird.

Grounded in Swift Evolution and `swiftlang/swift-foundation`. The TileKit engine targets macOS and Linux (a server-style Apple + Linux split), so it falls under Topology 2/3 below. Subprocess and shell-out are available on both macOS and Linux; the engine may use them.

## Linux portability and the platform seam (mandatory)

The engine targets macOS and Linux. Two obligations follow:

1. Guard every platform-divergent line, preferring `#if canImport(<Framework>)` over `#if os(...)` so future platforms inherit the right branch.
2. Check Linux availability before adding a dependency. Many Apple frameworks, and the packages that wrap them, do not build on Linux.

When the same functionality needs a different implementation per platform, abstract it behind a protocol seam; do not branch at call sites. Define a foundation-only protocol (see [shared-protocols.md](shared-protocols.md)), implement it once per platform (a macOS target using the Apple package, a Linux target using a Linux-available package), and let the composition root wire the correct one (see [dependency-injection.md](dependency-injection.md)). The core depends only on the protocol.

```swift
public protocol ClockService: Sendable { var now: Date { get } }
#if canImport(Darwin)
let clock: any ClockService = DarwinClock()
#else
let clock: any ClockService = LinuxClock()
#endif
```

## Three topologies (pick one before designing)

The rest of this rule depends on which topology your target is in. Mixing them silently is the root cause of most cross-platform breakage.

1. **Apple-only.** iOS, macOS, plus optional visionOS/tvOS/watchOS. UI-heavy, SwiftUI or UIKit/AppKit primary. No Linux build, no server-side targets.
2. **Apple clients + Linux server (split package).** UI lives on Apple, one or more server products build to Linux. The Linux-buildable surface is narrow (typically a single server product). Apple-only stuff is wrapped in conditional product/target arrays in `Package.swift`.
3. **Cross-platform library or CLI.** Runs identically on Apple + Linux + Windows. No UI. Probably uses URLSession-via-FoundationNetworking, Darwin/Glibc conditionals, swift-system. The TileKit engine lives here (macOS + Linux): both platforms support subprocess and shell-out, so the engine may spawn subprocesses when needed.

A "Linux UI" topology technically exists but is not production-grade. Do not try to render SwiftUI on Linux; if a server needs UI, ship HTTP responses (templates, JSON for an SPA), not native widgets.

## Three layers of platform conditioning

Each topology uses some combination of these. The layer determines which directive is correct.

### Layer A: `Package.swift` manifest

Use `#if os()` only. **Never `#if canImport()`** in the manifest. The manifest is parsed eagerly; `canImport` is evaluated lazily and silently breaks Linux CI.

Apple-only products and targets go in conditional arrays so non-Apple builds see an empty list:

```swift
#if os(iOS) || os(macOS)
let appleOnlyProducts: [Product] = [
    .singleTargetLibrary("TileDownUI"),
    .singleTargetLibrary("TileDownComponents"),
    // ...
]
#else
let appleOnlyProducts: [Product] = []
#endif
```

Same pattern for `appleOnlyTargets`. Core engine products (e.g. `TileKit`) stay unconditional.

### Layer B: Swift source files

Prefer `#if canImport(<framework>)` over `#if os(<platform>)` for framework gating. canImport is robust to new Apple platforms inheriting the framework; explicit platform lists need updating each time a new OS ships.

Canonical use cases:

- `#if canImport(UIKit)` for UIKit types (iOS, tvOS, visionOS)
- `#if canImport(AppKit)` for AppKit types (macOS)
- `#if canImport(FoundationNetworking)` for URLSession on Linux (see Server patterns below)
- `#if canImport(Darwin)` / `#elseif canImport(Glibc)` for low-level POSIX C (read, write, ioctl)
- `#if canImport(os)` for Apple's unified logging (`os.log`)

Reserve `#if os(<platform>)` for behaviour that genuinely varies by OS even when the same framework is present, e.g. iOS-only SwiftUI modifiers that exist alongside macOS SwiftUI.

### Layer C: Per-target dependency conditioning

For a target that is mostly cross-platform but has one Apple-only dependency, use `.when(platforms:)`:

```swift
.target(
    name: "TileRenderer",
    dependencies: [
        "TileModels",
        .product(name: "CryptoKit", package: "swift-crypto"),
    ].when(platforms: [.macOS])
)
```

Avoid spreading platform conditioning across both Layer A and Layer C for the same target; pick one place per concern.

## UI cross-platform patterns

These patterns (Patterns 1-7 and Pattern 13: iOS-only SwiftUI modifiers, UIKit/AppKit app shells, the forward-compat SDK shim, and the `@available(iOS ...)` examples) describe the planned native Apple UI app, NOT the TileKit engine. The engine targets macOS + Linux and has no UI. Apply these only in the app tier.

Linux UI is out of scope (no SwiftUI on Linux).

### Pattern 1: Apple-only UI file (outer gate)

A SwiftUI file that has no Linux meaning gets a file-level gate:

```swift
// TileDownUI/MainTabs.swift
import SwiftUI

#if os(iOS) || os(macOS)

public struct MainTabs: View {
    public var body: some View { ... }
}

#endif
```

The whole file is skipped on Linux. This is the default for UI source files in an Apple-clients-plus-Linux-server topology. Without the outer gate, a Linux build pulling the same source tree hits compile errors on SwiftUI.

### Pattern 2: iOS-only SwiftUI modifier on a cross-Apple view (inline gate)

A view that runs on both iOS and macOS, with one modifier that exists only on iOS:

```swift
public struct TileListView: View {
    public var body: some View {
        List(tiles) { ... }
        #if os(iOS)
            .toolbar { EditButton() }       // iOS-only
            .listStyle(.insetGrouped)        // iOS-only
            .navigationBarTitleDisplayMode(.inline)  // iOS-only
        #endif
    }
}
```

Use this when the file is already inside an Apple-only outer gate (Pattern 1), and only specific SwiftUI modifiers need iOS-vs-macOS branching. Common iOS-only modifiers: `.toolbar { EditButton() }`, `.listStyle(.insetGrouped)`, `.navigationBarTitleDisplayMode()`, `.keyboardType()`, `.textInputAutocapitalization()`.

macOS-only modifiers (rarer): window-style toolbars, `.toolbar(.windowToolbar, ...)`, `.windowResizability()`.

### Pattern 3: UIKit/AppKit framework bridge (`canImport`)

When the same conceptual API ships under different framework names on each platform:

```swift
// TileColors/TileColors.swift
#if canImport(UIKit)
import UIKit
extension Color {
    public static let systemBackground = Color(uiColor: .systemBackground)
    public static let systemGroupedBackground = Color(uiColor: .systemGroupedBackground)
}
#elseif canImport(AppKit)
import AppKit
extension Color {
    public static let systemBackground = Color(nsColor: .windowBackgroundColor)
    public static let systemGroupedBackground = Color(nsColor: .underPageBackgroundColor)
}
#endif
```

Bridges from UIKit/AppKit primitives into unified SwiftUI types (Color, Image, Font). Use `canImport` on each branch, not `os()`. The `Color` API itself is cross-Apple; only the bridge to the framework-specific colour is platform-specific.

### Pattern 4: Layered `canImport` outer + `os()` inner

The combined pattern when both the framework gate AND the per-platform behaviour matter:

```swift
// TileColors/Color+Dynamic.swift
#if canImport(UIKit)
import UIKit

extension Color {
    public static func dynamic(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { trait in
            #if os(iOS)
            return trait.userInterfaceStyle == .dark ? dark.uiColor : light.uiColor
            #else
            // tvOS, visionOS handle dynamic colours differently
            return light.uiColor
            #endif
        })
    }
}
#elseif canImport(AppKit)
import AppKit
// macOS dynamic-color implementation
#endif
```

The outer `canImport(UIKit)` gates whether UIKit is available; the inner `os(iOS)` distinguishes iOS from other UIKit-using platforms (tvOS, visionOS). Useful when one framework has multiple consumers with different APIs.

### Pattern 5: Apple-only logging via `canImport(os)`

Apple's unified logging (`os.log`, `Logger`) does not exist on Linux. Gate on the framework, fall back to `print` on Linux:

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

    public func info(_ message: String) { print("[INFO] \(message)") }
    public func error(_ message: String) { print("[ERROR] \(message)") }
}
#endif
```

Using `canImport(os)` rather than `os(macOS) || os(iOS) || os(visionOS) || os(tvOS) || os(watchOS)` is the gold-standard pattern. Future Apple platforms inherit `os` automatically; explicit platform lists rot.

### Pattern 6: SwiftUI app target per platform, shared feature package

Separate Xcode projects for iOS and macOS apps, same SwiftUI feature package providing the root view. Keep the platform-specific app shells thin; put the shared UI in one feature package.

### Pattern 7: UIKit (iOS) and AppKit (macOS) app shells, shared feature package

When the app target must be UIKit (iOS scene delegate) or AppKit (NSWindowController), with the feature package providing platform-specific factory functions (`createMainWindow(for:)` / `createWindowController()`). Cross-platform abstractions for the shared types (`PlatformView`, `PlatformViewController`) live in a native-UI package.

### Pattern 13: Forward-compat shim for unreleased Apple APIs

When the next SDK release will ship a new SwiftUI / Apple API and you want call sites to use it now without rewriting later, build a forward-compat wrapper. Single edit when the real API ships; zero call-site changes.

**Shape:**

1. A wrapper struct on `View` (or whatever the host type is) that takes the wrapped content.
2. A namespace accessor as a computed property: `var upcoming: SwiftUIUpcoming<Self>`. Call sites read `view.upcoming.<method>(...)`.
3. **Mirror types** (`UpcomingGlass`, `UpcomingGlassEffectTransition`, etc.): enums or structs with the same shape as the not-yet-shipped Apple types. They exist today so call sites can reference them; when the real types ship, a single `#if false` to real-mapping flip converts them.
4. **Fallback bodies** on the wrapper's methods that return the closest current-SDK approximation. `glassEffect` returns `content.clipShape(shape)`; `glassEffectTransition` returns `content` unchanged; etc. No call-site `if #available` ceremony needed.
5. **`#if false` blocks** holding the future mapping from mirror types to real Apple types, annotated with the future `@available(iOS 26, macOS 26, *)` (or whatever the target SDK is). When that SDK is the build target, flip `#if false` to `#if canImport(<NewFramework>)` or just remove the gate.

**Worked example (abbreviated):**

```swift
import SwiftUI

public struct SwiftUIUpcoming<Content> {
    public let content: Content
    public init(_ content: Content) { self.content = content }
}

@available(iOS 18, macOS 15, *)
public extension View {
    var upcoming: SwiftUIUpcoming<Self> { SwiftUIUpcoming(self) }
}

@available(iOS 18, macOS 15, *)
public enum UpcomingGlass: Equatable, Sendable {
    case regular
    case clear
    case tinted(Color?)
    case interactive(isEnabled: Bool)
    // ... mirror the upcoming Apple type's cases
}

@MainActor
@available(iOS 18, macOS 15, *)
public extension SwiftUIUpcoming where Content: View {
    func glassEffect(_ glass: UpcomingGlass = .regular, in shape: some Shape = Capsule()) -> some View {
        // Fallback for current SDK. Real glassEffect ships in iOS 26 / macOS 26.
        content.clipShape(shape)
    }
}

// Real API mapping. Flip to `#if canImport(...)` or remove gate when iOS 26 / macOS 26 is the build target.
#if false
@available(iOS 26, macOS 26, *)
extension UpcomingGlass {
    var toGlass: Glass {
        switch self {
        case .regular: .regular
        case .clear: .clear
        case .tinted(let color): .regular.tint(color)
        case .interactive(let isEnabled): .regular.interactive(isEnabled)
        }
    }
}
#endif
```

**When to use:**

- A new SwiftUI / UIKit / AppKit API is announced for the next major Apple release and you want call sites to start adopting it before you can build against the new SDK.
- The new API's shape is stable enough that you can mirror its types reasonably (single Apple beta release usually shows the final surface).
- You want a single switchover point when the new SDK ships, not a sweep through every call site.

**When NOT to use:**

- The API's shape is still in flux (avoid mirror-type rot).
- The fallback would be misleading (e.g. a security-sensitive API where "no-op fallback" silently weakens the contract; better to gate the call site explicitly with `if #available`).
- The codebase ships before the new SDK is final and you do not actually need pre-adoption (just wait).

**Naming:**

The accessor name and wrapper name are project conventions. `upcoming` and `SwiftUIUpcoming<Content>` are the defaults. Mirror types prefixed with `Upcoming` (e.g. `UpcomingGlass`) for findability. Do not use `Forward*` or `forwards`; the name is too generic and collides with view-forwarding patterns.

**Aging:**

When the new SDK ships:

1. Replace `#if false` with the real availability gate (`#if canImport(<NewFramework>)` or just remove the gate if the SDK is the build minimum).
2. Replace fallback method bodies with `if #available { real API } else { fallback }`.
3. Eventually, when the deployment target moves to the new SDK, delete the wrapper entirely and rewrite call sites to use the real API directly. Plan for this; the wrapper is transitional, not permanent.

## Server cross-platform patterns

A Linux server topology typically uses Vapor + AsyncHTTPClient + Fluent + OpenAPI. The key design decision: **avoid URLSession on the server path entirely**. AsyncHTTPClient abstracts POSIX networking and works on Linux without source-level conditionals.

### Pattern 8: AsyncHTTPClient over URLSession (server pattern)

For any server-side HTTP code that needs to build on Linux, use `swift-server/async-http-client`:

```swift
import AsyncHTTPClient
import NIOHTTP1

let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
let request = HTTPClientRequest(url: "https://example.com/api")
let response = try await httpClient.execute(request, timeout: .seconds(30))
let body = try await response.body.collect(upTo: 1024 * 1024)
```

No `#if canImport(FoundationNetworking)` needed. AsyncHTTPClient is the canonical cross-platform HTTP client on the server side.

### Pattern 9: Vapor (or Hummingbird) on Linux

Vapor + Fluent-SQLite + OpenAPI builds and runs on Linux out of the box. Manifest declares the package dependencies; no source-level platform conditionals required for the server targets. Production deployment is typically via Docker (`swift:6.0-jammy` or later).

Anti-pattern: pulling `URLSession`-based code into a Vapor handler. The handler now needs FoundationNetworking conditional + the rest of the rule below.

### Pattern 10: FoundationNetworking conditional (library pattern, not server)

For cross-platform library code that uses URLSession (Topology 3), conditionally import FoundationNetworking BEFORE Foundation:

```swift
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Foundation

let url = URL(string: "https://example.com/api")!
let (data, response) = try await URLSession.shared.data(from: url)
```

`URLSession` lives in `Foundation` on Apple and in `FoundationNetworking` on Linux (where `Foundation` is `swift-corelibs-foundation` and re-exports `FoundationNetworking`). Conditionally importing `FoundationNetworking` first ensures the type is in scope on both platforms.

Reference: `swiftlang/swift-foundation/README.md` documents the three-tier architecture (Darwin Foundation.framework / `swift-foundation` toolchain / `swift-corelibs-foundation` Linux fallback).

### Pattern 11: Darwin / Glibc conditional for low-level C (or use swift-system)

For raw POSIX (read, write, ioctl, stat, file descriptors):

**Legacy pattern (still works):**

```swift
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

var ws = winsize()
_ = ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws)
```

**Preferred modern pattern, `apple/swift-system` + `CInterop`:**

```swift
import SystemPackage

let fd = try FileDescriptor.open("/path", .readOnly)
defer { try? fd.close() }
let bytes = try fd.read(into: buffer)
```

`swift-system` provides a unified, type-safe surface over Darwin/Glibc/Windows. Reference: SYS-0008 (CInterop.stat back-deploy), SE-0063 / SE-0208 (system packages).

When to use which: legacy code or operations not covered by `swift-system` use the Darwin/Glibc canImport pattern; new code reaches for `swift-system` first.

### Pattern 12: Logging on the server path (`canImport(os)` + print fallback)

Pattern 5 (logging via `canImport(os)`) applies to server code too. On Linux the logger falls back to `print()`; in production Linux deployments, redirect stdout/stderr to the host's logging facility (journald, Docker logs, etc.).

For more sophisticated logging that's cross-platform native, use `apple/swift-log` (`Logging` package, SSWG standard). Single `LogHandler` protocol works identically on Apple and Linux.

## Linux-buildable target rules (the parity gaps)

`swift-corelibs-foundation` (the Linux Foundation re-implementation) has improved significantly in Swift 5.9 / 6.x but still has gaps. Avoid these in any code that must run on Linux:

- `NSKeyedArchiver` / `NSKeyedUnarchiver`. Use `Codable` + JSON instead.
- Full `NSXMLParser` / `NSXMLDocument`. Use a third-party XML parser if you need DOM-level access.
- `NSEnergyFormatter` and some specialty formatters.
- Distributed notifications, `NSHostName`.

Prefer `swift-foundation`'s `FoundationEssentials` and `FoundationInternationalization` for new code; they ship the same implementation on every platform.

## Test framework on cross-platform code

Swift Testing (`@Test`, `@Suite`, `#expect`, `#require`) is platform-agnostic by design. Use it for cross-platform tests:

```swift
import Testing

@Test func crossPlatformBehaviour() async throws {
    let result = try await renderer.render(tile)
    #expect(result == .expected)
}
```

XCTest still works on Linux (auto-discovery since Swift 5.4; `LinuxMain.swift` no longer required), but Swift Testing avoids historical parity gaps. For new tests in a cross-platform target, default to Swift Testing.

If a specific test needs to skip on a platform:

```swift
@Test(.disabled(if: ProcessInfo.processInfo.environment["CI"] == "linux"))
func appleOnlyTest() { ... }
```

Or simpler, gate the whole test file with `#if os(...)`. Both are fine; the `.disabled` form gives the test runner a record.

References: ST-0009, ST-0016, ST-0017, ST-0022 (Swift Testing cross-platform behaviour).

## CI requirements

### If your repo ships any Linux-buildable product

Linux CI runs on every PR. Minimum job:

```yaml
linux-build:
  runs-on: ubuntu-latest
  container: swift:6.0-jammy
  steps:
    - uses: actions/checkout@v4
    - run: swift build -c release --product <your-linux-product>
```

Without this, the Linux build can rot silently between deploys. The Docker production deploy is not a CI substitute; it finds breakage at deploy time, not PR time.

### If your repo is Apple-only (Topology 1)

macOS CI is sufficient. Optional iOS Simulator + visionOS simulator on tagged PRs.

### Linux test job (when you have Linux-buildable tests)

```yaml
linux-test:
  runs-on: ubuntu-latest
  container: swift:6.0-jammy
  steps:
    - uses: actions/checkout@v4
    - run: swift test --filter <LinuxBuildableTestSuite>
```

Run only the test suites known to be Linux-buildable; gate the others with `#if os(iOS) || os(macOS)` at the file level.

## Manifest discipline for split-topology repos (Topology 2)

If your repo ships an Apple-clients-plus-Linux-server split:

1. **Declare Apple platforms in `platforms:`**. There is no stable Linux entry in the SPM platforms enum; Linux support is implicit when the package builds on a Linux toolchain. For the engine (macOS + Linux), declare macOS only: `platforms: [.macOS(.v15)]`. A repo that also ships an Apple UI app tier adds `.iOS(.v18)` for that tier.

2. **Document the Linux-buildable surface.** In the repo's `README.md` / `AGENTS.md`, name the products that build to Linux: e.g. "On Linux, build the server product only: `swift build --product tiledownserver`." Otherwise a new developer running `swift build` on Linux hits confusing errors from Apple-only targets.

3. **Wrap Apple-only products and targets in conditional arrays** (Layer A pattern above). This is the load-bearing rule that makes Layer-A discipline work.

4. **Server-side targets stay unconditional.** Do not accidentally wrap an unconditional server product in `#if os(iOS) || os(macOS)`; that is the most common error in this topology.

## Fallthrough discipline

If your code runs on Linux in production, every `#if os(...)` chain that affects observable behaviour needs an explicit `#elseif os(Linux)` arm.

Bad (User-Agent header reports "unknown" on Linux even though we ship there):

```swift
#if os(iOS)
return "Tiledown/iOS/\(version)"
#elseif os(macOS)
return "Tiledown/macOS/\(version)"
#elseif os(visionOS)
return "Tiledown/visionOS/\(version)"
#else
return "Tiledown/unknown/\(version)"  // Linux falls into "unknown"
#endif
```

Good:

```swift
#if os(iOS)
return "Tiledown/iOS/\(version)"
#elseif os(macOS)
return "Tiledown/macOS/\(version)"
#elseif os(visionOS)
return "Tiledown/visionOS/\(version)"
#elseif os(Linux)
return "Tiledown/Linux/\(version)"
#else
return "Tiledown/unknown/\(version)"  // truly unknown future platform
#endif
```

The `#else` arm is reserved for platforms you genuinely do not run on; every platform you DO run on gets a named arm. Otherwise metrics, telemetry, and feature toggles silently lump Linux into "unknown."

## Cross-references

- `docs/rules/linux-server.md` is the server-specific operational layer (AsyncHTTPClient, swift-log, graceful shutdown, Docker). Load both together for a server repo.
- `concurrency.md` is platform-agnostic; Sendable + async/await behave identically on Apple and Linux.

## Authoritative references

- **Foundation architecture**: `swiftlang/swift-foundation` README, the three-tier model (Darwin / swift-foundation / swift-corelibs-foundation).
- **System packages**: SE-0063, SE-0113, SE-0208.
- **swift-system CInterop**: `apple/swift-system` Proposals/0008-backdeploy-cinterop-stat.md.
- **Swift Testing cross-platform**: ST-0009, ST-0016, ST-0017, ST-0022.
- **swift-log (SSWG logger)**: `apple/swift-log`.
- **Vapor / AsyncHTTPClient / Hummingbird**: their respective package docs.

## Quick reference table

| Concern | Apple-only (T1) | Apple+Linux split (T2) | Cross-platform (T3) |
|---|---|---|---|
| Package.swift platforms | `[.iOS, .macOS, ...]` | `[.iOS, .macOS]` + document Linux products | `[.iOS, .macOS, ...]`, Linux implicit |
| Manifest `#if` | rare | `#if os(iOS) \|\| os(macOS)` for Apple-only product/target arrays | Apple-only product/target arrays plus `.when(platforms:)` |
| Source files | `#if os(iOS) \|\| os(macOS)` if needed | outer gate on UI files | `#if canImport(<framework>)` |
| HTTP | URLSession | AsyncHTTPClient on server, URLSession on client | `canImport(FoundationNetworking)` + URLSession |
| C interop | `import Darwin` | `import Darwin` on Apple, none on server | `swift-system` or canImport(Darwin)/Glibc |
| Logging | `os.log` directly | `canImport(os)` + `print` fallback or `swift-log` | `swift-log` or `canImport(os)` + fallback |
| Tests | Swift Testing | Swift Testing, Linux-buildable suites separate | Swift Testing |
| CI | macOS only | macOS + Linux Docker job for the Linux product | macOS + Linux + (Windows) |
| Linux UI | n/a | server-side: HTTP responses, not native widgets | n/a |
