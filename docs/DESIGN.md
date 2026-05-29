# Cupertino Desktop: Architecture & Design

Status: design draft. Target the cupertino MCP backend as it exists on `cupertino@develop`.

## 1. Goals & non-goals

**Goals**

- Native Apple app for browsing Apple developer docs, Swift Evolution, and sample code offline. macOS first (macOS 15+, Swift 6.2+, Xcode 16+); iOS (iPhone/iPad) is an explicit design target, not a someday-maybe.
- Be a thin client over the `cupertino` corpus, reached through one backend seam with several implementations. Do **not** reimplement search, indexing, or storage. We are **not** "an MCP app": MCP is merely the wire that one local conformer happens to speak to a `cupertino serve` subprocess (section 5), one option among several, not the system's identity.
- The backend is reached through one protocol seam, and **how** it connects (local subprocess, embedded in-process, future remote) is itself chosen by protocol, per platform.
- Ship parallel UI targets that differ only in framework: macOS SwiftUI + macOS AppKit now; iOS SwiftUI + iOS UIKit as the same exercise on iOS. All consume the identical backend seam.
- Follow the ExtremePackaging monorepo convention: `Main.xcworkspace` at root, single `Package.swift` in `Packages/`, app targets in `Apps/`, layered packages. Every package depends only on protocol (seam) packages; concrete packages never import each other; `*Impl` packages are the only place concretes are composed.

**Non-goals**

- No crawling, downloading, or index building in this app. The cupertino server (subprocess on macOS, embedded library on iOS) owns all of that.
- No re-parsing of HTML or building a second search index.
- No visionOS/watchOS targets yet (the layering keeps that door open).

## 2. Backend reality (what we actually build against)

There are, from first principles, three ways to reach cupertino, and locality is the axis: **in-process** (embedded, no protocol at all), **out-of-process on this machine** (a `cupertino serve` subprocess), and **remote** (future, over the network). Only the out-of-process paths need a wire protocol, and the one cupertino happens to expose to a separate process is MCP (JSON-RPC tools): send a request, get a (mostly markdown) string back. So MCP is real, but it is a property of *one mechanism of one conformer*, not of the system.

What the cupertino package gives us, and what it does not:

- **`MCPCore`** (cross-platform, the one product not gated behind `#if os(macOS)`): the JSON-RPC + MCP protocol types (`Request`, `CallToolResult`, `Tool`, `Resource`, ...). We reuse these types verbatim in the MCP conformer.
- **`MCP.Client`** (the upstream client `actor`): spawns `cupertino serve` and talks stdio. It is **stdio-hardcoded**: it constructs a `Process` directly and has no transport injection point. So we do **not** build on it. The MCP conformer owns a small client that speaks JSON-RPC over `any Transport` (our seam, section 5.2), which is what makes a future remote transport possible without forking the protocol.
- **Everything else** in cupertino (search, indexing, storage, the `CompositeToolProvider`, `Services`) is **macOS-only today** (`platforms: [.macOS(.v13)]`, `#if os(macOS)`). This is the constraint that shapes the iOS story (section 5.4).

### 2.1 Connection lifecycle (our client, transport-agnostic)

```swift
let transport: any Transport = SubprocessTransport(command: "cupertino", arguments: ["serve"])
let client = MCPClient(transport: transport)
try await client.connect()    // transport.start() + MCP `initialize` handshake
// ... callTool / readResource ...
await client.disconnect()      // transport.stop()
```

`connect()` starts the transport (which, for the subprocess transport, launches the process and wires its pipes) and performs the MCP `initialize` handshake. The same client runs unchanged over a future remote transport. This client and its transports are used **only** by the macOS MCP conformer (section 5.2); the embedded conformer does not use them at all.

### 2.2 Low-level surface

```swift
func listTools() async throws -> [Tool]
func callTool(name: String, arguments: [String: AnyCodable]?) async throws -> CallToolResult
func listResources() async throws -> [Resource]
func readResource(uri: String) async throws -> ReadResourceResult
```

### 2.3 Convenience wrapper (subset)

`MCP.Client.Cupertino.swift` wraps a subset and returns **strings**:

| Method | Tool | Args | Returns |
|---|---|---|---|
| `searchDocs` | `search_docs` | `query`, `limit` | markdown |
| `searchSamples` | `search_samples` | `query`, `framework?`, `limit` | markdown |
| `listSamples` | `list_samples` | `framework?`, `limit` | markdown |
| `readSample` | `read_sample` | `project_id` | markdown |
| `readSampleFile` | `read_sample_file` | `project_id`, `file_path` | syntax-highlighted text |
| `readDocumentation` | (resource) | `uri` e.g. `apple-docs://swiftui/documentation_swiftui_view` | markdown |

### 2.4 Full server tool catalog (reachable via `callTool`)

The MCP server exposes more than the wrapper covers. The **framework browser's 261 frameworks come from `list_frameworks`**, which has no convenience method, so call it directly.

`search`, `list_frameworks`, `list_samples`, `read_document`, `read_sample`, `read_sample_file`, `get_inheritance`, `search_symbols`, `search_conformances`, `search_generics`, `search_concurrency`, `search_property_wrappers`.

### 2.5 THE central constraint

**Every backend result is a formatted markdown/text string, not a typed model.** This drives the whole architecture:

1. We render markdown natively (doc reader, search results): strings are a feature, not a bug, for the reader.
2. For list/tree UIs (frameworks sidebar, search result rows, sample file trees) we need structure. Two options, decided per-tool in §6:
   - **(A) Parse the markdown** the server returns into models in an Infrastructure layer.
   - **(B) Bypass the wrapper**, call the raw tool, and parse the richer `CallToolResult` content (may contain JSON).
   - Preference: (B) where the raw tool returns JSON; (A) only where it does not. A spike in milestone M1 (§13) determines which tools give JSON.

## 3. Repo layout (ExtremePackaging)

Packages fall into three kinds, and the kind dictates what a package may import:

- **API (seam) packages**: protocols + value types only. Zero dependencies on concrete siblings. Cross-platform.
- **Concrete packages**: one responsibility each. Depend only on API packages (and at most one external library). Concrete packages never import each other.
- **Impl (composition) packages**: the only packages allowed to import multiple concretes and wire them together. Apps depend on an Impl package plus a UI package, nothing more.

```
cupertino-desktop/
├── Main.xcworkspace                 # opens Packages + all app projects
├── Packages/
│   ├── Package.swift                # single manifest, all library targets
│   ├── Sources/
│   │   # --- API / seam packages (protocols + value types only) ---
│   │   ├── AppModels/           # value types (Framework, DocPage, SearchHit, ...)
│   │   ├── BackendAPI/              # DocumentationBackend protocol + errors (the ONLY universal seam)
│   │   ├── TransportAPI/         # Transport protocol; internal to the MCP conformer
│   │   ├── CatalogStoreAPI/         # CatalogStore protocol (where the DBs live; embedded path)  [future]
│   │   ├── AppCore/             # UI namespace + framework-agnostic RootModel
│   │   # --- Concrete packages (depend only on API packages) ---
│   │   ├── MCPClientKit/            # JSON-RPC client over `any Transport` (+ MCPCore types)
│   │   ├── SubprocessTransport/     # Transport: spawns `cupertino serve` (macOS)
│   │   ├── RemoteTransport/         # Transport: HTTP/SSE to a remote MCP server (future)
│   │   ├── LocalSubprocessBackend/              # DocumentationBackend conformer over MCPClientKit; maps -> AppModels
│   │   ├── LocalEmbeddedBackend/         # DocumentationBackend conformer via direct cupertino calls (future, iOS+mac)
│   │   ├── BundledCatalogStore/     # CatalogStore: DBs shipped as app resources         [future]
│   │   ├── DownloadableCatalogStore/# CatalogStore: fetch + cache DBs on first run        [future]
│   │   ├── MarkdownRendering/       # markdown string -> display models
│   │   ├── SearchFeature/ ...       # @Observable view models (depend on BackendAPI only)
│   │   ├── ShellSwiftUI/ ShellAppKit/   # native window/navigation shells
│   │   └── <Feature>SwiftUI / <Feature>AppKit/   # per-feature screen pairs (added per feature)
│   │   # --- Impl / composition packages (wire concretes together) ---
│   │   ├── MacBackendImpl/          # LocalSubprocessBackend over SubprocessTransport
│   │   └── LocalEmbeddedBackendImpl/     # LocalEmbeddedBackend + CatalogStore                       [future]
│   └── Tests/
├── Apps/
│   ├── CupertinoDesktopSwiftUI/     # macOS SwiftUI app  (ShellSwiftUI + MacBackendImpl)
│   ├── CupertinoDesktopAppKit/      # macOS AppKit app   (ShellAppKit  + MacBackendImpl)
│   ├── CupertinoMobileSwiftUI/      # iOS SwiftUI app    (iOS shell    + LocalEmbeddedBackendImpl)  [future]
│   └── CupertinoMobileUIKit/        # iOS UIKit app      (iOS shell    + LocalEmbeddedBackendImpl)  [future]
└── docs/
    └── DESIGN.md
```

Dependency direction is strictly one-way: **Foundation → Infrastructure → Features → UI → Apps**. Apps depend on one UI package; UI packages depend on Features/Core; nothing depends on Apps.

Types are namespaced under short per-module semantic anchors (`Model`, `Backend`, `Feature`, `UI`, `Markdown`); there is no project-name root prefix, since the Swift module already namespaces each target. So a type reads `UI.RootModel`, `Backend.LocalSubprocess`, `Feature.Search`.

## 4. Package architecture

### Foundation layer

- **`AppModels`**: pure value types: `Framework`, `DocPage`, `SearchHit`, `SampleProject`, `SampleFile`, `SymbolHit`, `DocURI`. `Sendable`, no dependencies. Make impossible states unrepresentable (e.g. `DocURI` is a validated wrapper, not a bare `String`).
- **`AppCore`**: shared protocols and errors: `DocumentationBackend` protocol (the seam, §5), `BackendError`, paging types.

### Infrastructure layer

- **`LocalSubprocessBackend`**: the single adapter that depends on the `cupertino` package's `MCP.Client`. Implements `DocumentationBackend`. Owns subprocess lifecycle, connection state, retries, and the string→model parsing/JSON extraction. **This is the only module that imports `cupertino`.** Everything above it sees the `DocumentationBackend` protocol, never `MCP.Client`.
- **`MarkdownRendering`**: converts server markdown strings to display models (AttributedString for SwiftUI, NSAttributedString for AppKit). Shared by both apps.

### Features layer (UI-framework-agnostic view models)

Each feature ships an `@Observable` view model that depends only on `DocumentationBackend` and the value types. It imports no UI framework (Observation only), so both UI packages bind to the exact same instance.

- **`SearchFeature`**: query box, result list, scopes (docs / samples / symbols).
- **`FrameworkBrowserFeature`**: sidebar of frameworks (`list_frameworks`), drill into a framework's pages.
- **`DocReaderFeature`**: render a `read_document` page, in-page nav, related symbols (`get_inheritance`, `search_conformances`).
- **`SampleBrowserFeature`**: `list_samples`, `read_sample` (project tree), `read_sample_file` (syntax-highlighted file viewer).

### UI layer (two parallel, fully native packages)

The UI ships as **two parallel packages that implement the same functionality, consumed through same-shaped protocols**. Neither fakes the other: there is no `NSHostingController`, no `NSViewControllerRepresentable`. The SwiftUI package imports only SwiftUI and vends real `some View`; the AppKit package imports only AppKit and vends real `NSViewController`.

- **`DesktopUISwiftUI`**: native SwiftUI views bound to the shared view models. Exposes `UI.RootExperience` (a protocol vending a SwiftUI `View`) with a `UI.LiveRootExperience` conformer.
- **`DesktopUIAppKit`**: native AppKit view controllers bound to the same view models. Exposes `UI.RootExperience` (the same qualified name and method shape, vending an `NSViewController`) with its own `UI.LiveRootExperience`.

The shared, framework-agnostic seam (`UI.RootModel` and the per-feature view models) lives in `AppCore`/Features so both packages bind identically. The two `RootExperience` protocols are parallel (idiomatic per framework: `some View` vs `NSViewController`), not one erased type, so neither side pays a hosting/erasure penalty.

### Apps layer

- **`CupertinoDesktopSwiftUI`**: `@main` App, `WindowGroup`, links `ShellSwiftUI` + `MacBackendImpl`, mounts `UI.LiveRootExperience().makeRoot(model:)`.
- **`CupertinoDesktopAppKit`**: `NSApplicationMain` + `NSApplicationDelegate`, `NSWindow`, links `ShellAppKit` + `MacBackendImpl`, mounts its `UI.LiveRootExperience().makeRoot(model:)` as the window content controller.

Each app is a pure composition + framework-specific entry point: it picks an Impl package (which fixes the transport) and a UI package (which fixes the framework). All logic is in Features; all views are in the UI packages. The iOS apps follow the same shape with `LocalEmbeddedBackendImpl`.

## 5. The backend seam and its conformers

There is exactly **one universal seam**: `DocumentationBackend`. Features and UI depend on it and nothing else. **MCP is not universal**: it is the wire protocol of one conformer (the macOS path, which has to speak MCP because `cupertino serve` only speaks MCP). Other conformers reach cupertino by other means, and they do not pretend otherwise.

```
Features / UI
     │  depends only on
     ▼
DocumentationBackend          (BackendAPI)   domain verbs, returns AppModels
     ├── LocalSubprocessBackend           (macOS now): MCP JSON-RPC over a Transport
     │        └── Transport   (TransportAPI): stdio now, remote later
     │              ├── SubprocessTransport   (spawn `cupertino serve`)
     │              └── RemoteTransport        (future: HTTP/SSE)
     └── LocalEmbeddedBackend      (iOS / mac, future): calls cupertino's read APIs
              directly in-process. No MCP, no JSON-RPC, no transport. Typed results.
```

The two conformers are independent and have nothing in common below `DocumentationBackend`. Adding a remote MCP server later is a new `Transport` under `LocalSubprocessBackend`; it does not touch `LocalEmbeddedBackend`. The embedded path's fidelity is *higher*, not lower, because it skips the markdown round-trip and reads cupertino's typed results.

### 5.1 `DocumentationBackend` (the only universal seam)

Pure domain language, returns `AppModels` value types, never leaks MCP or cupertino types. Both conformers honour the same contract.

```swift
public protocol DocumentationBackend: Sendable {
    func connect() async throws
    func disconnect() async

    func listFrameworks() async throws -> [Framework]
    func searchDocs(_ query: String, limit: Int) async throws -> [SearchHit]
    func readDocument(uri: DocURI) async throws -> DocPage          // markdown string inside

    func listSamples(framework: String?, limit: Int) async throws -> [SampleProject]
    func readSample(projectId: String) async throws -> SampleProject // includes file tree
    func readSampleFile(projectId: String, path: String) async throws -> SampleFile

    func searchSymbols(_ query: String, limit: Int) async throws -> [SymbolHit]
    func inheritance(forSymbol id: String) async throws -> DocPage
}
```

Registered as a Point-Free `DependencyKey` so features inject it uniformly and tests swap a fake:

```swift
extension DependencyValues {
    var backend: any DocumentationBackend { ... } // live = the Impl's conformer, test = FakeBackend()
}
```

`DocPage` carries the raw markdown plus parsed metadata so `DocReaderFeature` renders without re-fetching.

### 5.2 Conformer A: `LocalSubprocessBackend` (local, out-of-process)

This is the conformer that speaks MCP, because the only thing `cupertino serve` exposes to a separate process is the MCP JSON-RPC tool surface. It maps the (mostly markdown) tool results into models per the strategy table in section 6. MCP lives entirely inside this conformer and the packages it uses; nothing above `DocumentationBackend` sees it.

Internally it owns an `MCPClient` (`MCPClientKit`) that speaks JSON-RPC over a `Transport`. `MCPClientKit` reuses cupertino's cross-platform `MCPCore` types (we do not re-invent JSON-RPC), but does **not** use upstream `MCP.Client`, which is stdio-hardcoded with no injection point. The transport is the only swap point:

```swift
// TransportAPI: the seam internal to the MCP conformer (NOT a universal layer)
public protocol Transport: Sendable {
    func start() async throws
    func stop() async
    func send(_ frame: Data) async throws            // one JSON-RPC frame
    var inbound: AsyncThrowingStream<Data, Error> { get }
}
```

- **`SubprocessTransport`** (macOS): spawns `cupertino serve`, wires stdin/stdout, newline-delimited frames. The macOS production path today.
- **`RemoteTransport`** (future): HTTP + SSE (or WebSocket) to a remote cupertino MCP server, for a hosted/shared-corpus deployment. Not built in v1; the seam makes it additive.

### 5.3 Conformer B: `LocalEmbeddedBackend` (local, in-process)

iOS cannot spawn a subprocess, so there is no `cupertino serve` to talk to. The honest answer is **not** to run an in-process MCP server and talk to ourselves over a fake channel; it is to call cupertino's read APIs directly. `LocalEmbeddedBackend` conforms `DocumentationBackend` by calling the same services `cupertino serve` calls (`Services.ReadService`, `Search.Index`, `Sample.Index`, the production source registry), opening the SQLite DBs through a `CatalogStore` (section 5.5), and mapping cupertino's typed results into `AppModels`. No MCP, no JSON-RPC, no transport. This is the iOS production path and the higher-fidelity one.

**Hard upstream constraint**: cupertino's read targets are macOS-only today (`platforms: [.macOS(.v13)]`, `#if os(macOS)`, `FileManager.homeDirectoryForCurrentUser`). So `LocalEmbeddedBackend` is **not buildable for iOS** against cupertino as it stands. Per the maintainer's call ("most correct and highest fidelity, extremely refactored"), the plan is the proper upstream refactor in the cupertino repo: add the `.iOS` platform, split the read path cleanly from the macOS-only crawler/indexer/WebKit producers, and resolve all paths through injection (`Shared.Paths` is already path-DI). This is real cross-repo work, scheduled before the iOS apps (milestone M8), not a local shim.

### 5.4 Backend selection is itself by protocol

No package hard-codes which conformer it uses. The choice lives only in the `*Impl` composition packages, which an app target picks:

- **`MacBackendImpl`** = `LocalSubprocessBackend(MCPClient(SubprocessTransport(...)))`.
- **`LocalEmbeddedBackendImpl`** = `LocalEmbeddedBackend(catalog: ...)` (future).

### 5.5 Where the databases live on iOS (`CatalogStore`)

On macOS the corpus sits in the user's home directory, populated by `cupertino fetch`/`save`, and only the subprocess touches it. On iOS, `LocalEmbeddedBackend` opens the DBs itself, so it needs to know where they are. `CatalogStoreAPI` abstracts that; `LocalEmbeddedBackend` asks a `CatalogStore` for the URLs and never knows how they got there.

```swift
public protocol CatalogStore: Sendable {
    func databaseURLs() async throws -> CatalogDatabaseURLs   // search.db, samples.db, packages.db
}
```

- **`BundledCatalogStore`**: DBs shipped inside the app bundle as resources. Fully offline on first launch, but inflates app size and pins the corpus to app releases.
- **`DownloadableCatalogStore`**: on first run, download a versioned DB bundle into Application Support and cache it; check for updates later. Smaller binary, refreshable corpus, at the cost of a first-run download.

Default lean: bundle a small starter corpus, allow download of the full set. Decided when the iOS target is scheduled.

## 6. Per-tool model strategy (string to structure)

| Tool | UI need | Strategy | Notes |
|---|---|---|---|
| `list_frameworks` | tree/list | structured | spike: confirm JSON vs markdown table; parse into `[Framework]` |
| `search_docs` / `search` | result rows | structured | each hit: title, uri, snippet, framework |
| `read_document` | rendered page | string-as-is | render markdown; light parse for title/anchors |
| `list_samples` | list | structured | id, title, framework |
| `read_sample` | file tree | structured | project + file paths |
| `read_sample_file` | code view | string-as-is | already syntax-highlighted text; show in code component |
| `get_inheritance` / `search_conformances` | related panel | structured | symbol graph edges |

M1 spike (§13) records, per tool, whether the raw `CallToolResult` carries JSON (strategy B) or only markdown (strategy A parser in `LocalSubprocessBackend`). No parsing logic leaks above `LocalSubprocessBackend`. To build the parsers against real shapes, run `cupertino <tool>` (or the raw `tools/call`) and capture the output as a fixture; the server is the source of truth.

## 7. Connection management

Connection state is observable in either conformer (`ConnectionStatusBadge`): `idle -> connecting -> connected -> failed(reason)`. What "connect" means and how it fails differs by conformer:

- **`LocalSubprocessBackend` over `SubprocessTransport` (macOS)**: owns one long-lived `MCPClient`; the client `actor` serializes calls, so it adds no extra locking. Discover the `cupertino` executable (explicit path, then `PATH`); surface a clear "cupertino not found / docs not downloaded" empty state linking to install instructions rather than crashing. Reconnect on demand if the subprocess dies (a thrown client error on a call). Confirm App Sandbox entitlements permit spawning a subprocess, or ship non-sandboxed for the v1 dev tool.
- **`LocalSubprocessBackend` over `RemoteTransport` (future)**: same client, but network reachability, auth, and latency become the failure modes; same observable state machine.
- **`LocalEmbeddedBackend` (iOS / mac, future)**: no process and no transport. "Connect" means resolving the corpus via `CatalogStore` and opening the SQLite DBs; failure is a missing/locked/old corpus (first-run download or bundled-corpus error). Startup cost is opening the DBs, not spawning.

## 8. State & view-model design

- ViewModels are `@Observable` classes holding `@Dependency(\.backend)`, exposing async load methods and `LoadState<T>` (`idle / loading / loaded(T) / failed(Error)`). Make impossible states unrepresentable; never force-unwrap.
- SwiftUI views use `@Bindable` over the ViewModel. AppKit controllers observe the same `@Observable` via `withObservationTracking` (or a small `Observations` bridge) to drive `NSView` updates.
- Navigation: a single `AppRoute` enum (`.search`, `.framework(id)`, `.document(uri)`, `.sample(id)`) drives both shells (the `NavigationSplitView` path in SwiftUI, selection state in the AppKit split controller).

## 9. Concurrency

- Swift 6 strict concurrency. All models `Sendable`. Backend is an actor; ViewModels are `@MainActor`.
- Long calls (search, read) run as structured `Task`s owned by the ViewModel, cancelled on view disappearance / new query (debounce search input ~250ms).

## 10. Testing

- Swift Testing (`@Test`, `@Suite`, `#expect`), `withDependencies` to inject `FakeBackend`.
- `FakeBackend` returns fixture strings (capture real `cupertino serve` output once, store under `Packages/Tests/Fixtures/`) to test the parsers in `LocalSubprocessBackend` against real shapes.
- Each seam is independently fakeable: a fake `Transport` feeds canned frames to test `MCPClient`; a fake `CatalogStore` feeds temp DB URLs to test the embedded path. Concrete packages stay unit-testable in isolation because they import only protocols.
- Parameterized tests for the markdown/JSON parsers (`@Test(arguments:)`).
- No tests spawn the real subprocess except one opt-in integration smoke test, gated behind an env flag.

## 11. Why parallel apps share one backend

The compare-then-decide plan works only if the comparison is fair: identical backend, identical models, identical features, with the **only** variable being the UI framework. The seam layering guarantees that. macOS runs SwiftUI and AppKit side by side over `MacBackendImpl`; iOS will run SwiftUI and UIKit over `LocalEmbeddedBackendImpl`. When a framework decision is made, the losing `Apps/` target is deleted and nothing else changes. Swapping a transport (adding remote, moving iOS from bundled to downloadable corpus) touches one concrete package plus one Impl package, never a feature or a view.

## 12. Open questions (decision log)

1. **JSON vs markdown per tool**: resolved by M1 spike; recorded in §6 table.
2. **Markdown renderer**: native `AttributedString(markdown:)` vs a richer parser (swift-markdown) for code blocks/tables. Lean native first; escalate only if doc fidelity is poor.
3. **App target form**: `.xcodeproj` per app vs SwiftPM executable app targets in the workspace. Default: `.xcodeproj` per app under `Apps/` (better for entitlements, sandboxing, signing) referencing the `Packages` manifest.
4. **macOS sandboxing**: the macOS app spawns a subprocess; confirm App Sandbox entitlements allow it, or ship non-sandboxed for v1 (dev tool). Decide before any distribution work.
5. **Pinning the cupertino dependency**: local path during dev vs tagged SPM release. Default: local path (`../cupertino`) until the desktop app stabilizes.
6. **iOS embedding upstream**: making cupertino's read-path targets iOS-buildable (section 5.4) is a change in the *cupertino* repo, not here. Schedule that before committing to the iOS apps. Open: do it as a focused upstream PR now, or design-only until macOS ships?
7. **iOS corpus delivery**: bundled vs downloadable `CatalogStore` (section 5.5). Default lean: small bundled starter + downloadable full set. Confirm when the iOS target is scheduled.

## 13. Milestones

- **M0 (Skeleton)**: `Main.xcworkspace`, `Packages/Package.swift` with empty layered targets, both macOS `Apps/` targets launching an empty `NavigationSplitView` / `NSSplitViewController`. Compiles, runs, does nothing.
- **M1 (Backend seam + spike)**: `BackendAPI`, `TransportAPI`, `MCPClientKit`, `SubprocessTransport`, `LocalSubprocessBackend` over the subprocess transport, `MacBackendImpl`, `FakeBackend`. Spike each tool to fill the §6 strategy table. First real call: `list_frameworks` into the sidebar.
- **M2 (Read path)**: framework browser → doc reader rendering `read_document` markdown in both apps.
- **M3 (Search)**: debounced `search_docs` with scopes; result rows navigate to reader.
- **M4 (Samples)**: `list_samples` → `read_sample` tree → `read_sample_file` code viewer.
- **M5 (Symbols & polish)**: `get_inheritance` / conformances related panel; connection-status UX, empty/first-run states, error handling.
- **M6 (Compare & decide, macOS)**: evaluate SwiftUI vs AppKit on macOS, pick one or keep both, delete any losing target.
- **M7 (Embedded backend, macOS)**: `LocalEmbeddedBackend` calling cupertino's read APIs directly in-process (no MCP), proving the same features run with typed results. macOS only; exercises the direct-call mapping before the iOS port.
- **M8 (iOS, gated on upstream)**: land the cupertino iOS-buildability refactor (section 5.3), add `CatalogStore` conformers, ship `CupertinoMobileSwiftUI` + `CupertinoMobileUIKit` over `LocalEmbeddedBackendImpl`.
- **M9 (Remote, optional)**: `RemoteTransport` under `LocalSubprocessBackend` over HTTP/SSE for a hosted-corpus deployment, if a use case appears.
