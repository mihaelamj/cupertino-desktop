# Cupertino Desktop: Architecture & Design

Status: design draft. Target the cupertino MCP backend as it exists on `cupertino@develop`.

## 1. Goals & non-goals

**Goals**

- Native Apple app for browsing Apple developer docs, Swift Evolution, and sample code offline. macOS first (macOS 15+, Swift 6.2+, Xcode 16+); iOS (iPhone/iPad) is an explicit design target, not a someday-maybe.
- Be a thin client over the `cupertino` corpus, reached through one backend seam with several implementations. Do **not** reimplement search, indexing, or storage. We are **not** "an MCP app": MCP is merely the wire that one local conformer happens to speak to a `cupertino serve` subprocess (section 5), one option among several, not the system's identity.
- The backend is reached through one protocol seam, and **how** it connects is itself chosen by protocol. The first-order axis is **local vs remote** (remote is future). Today everything is local, in two flavors: **macOS talks to a local `cupertino serve` subprocess** (deliberately, to exercise the real Homebrew-installed binary), and **iOS runs cupertino's read path embedded in-process** (the only option on iOS, which cannot spawn a subprocess). **Embedded is mobile-only; the desktop is never embedded** because its whole point is to drive the real binary.
- Ship **six fully-native UI variants** over one shared set of view models, differing by device idiom and framework, never by logic: **macAppKit, macSwiftUI, iPhoneUIKit, iPhoneSwiftUI, iPadUIKit, iPadSwiftUI**. iPhone and iPad are *distinct* UIs (not one size-class-adaptive shell). No bridges: each imports only its own framework and vends a real native root. All six bind the identical `UI.RootModel` + feature view models and the identical backend seam.
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

`connect()` starts the transport (which, for the subprocess transport, launches the process and wires its pipes) and performs the MCP `initialize` handshake. The same client runs unchanged over a future remote transport. This client and its transports are used **only** by the macOS local-subprocess conformer (section 5.2); the embedded conformer does not use them at all.

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
│   │   ├── TransportAPI/         # Transport protocol; internal to the local-subprocess conformer's MCP client
│   │   ├── CatalogStoreAPI/         # CatalogStore protocol (where the DBs live; embedded path)  [future]
│   │   ├── AppCore/             # UI namespace + framework-agnostic RootModel
│   │   # --- Concrete packages (depend only on API packages) ---
│   │   ├── MCPClientKit/            # JSON-RPC client over `any Transport` (+ MCPCore types)
│   │   ├── SubprocessTransport/     # Transport: spawns `cupertino serve` (macOS)
│   │   ├── RemoteTransport/         # Transport: HTTP/SSE to a remote MCP server (future)
│   │   ├── LocalSubprocessBackend/              # Documentation conformer; talks to local `cupertino serve` via MCPClientKit; maps -> AppModels (macOS)
│   │   ├── LocalEmbeddedBackend/         # Documentation conformer via direct in-process cupertino calls; no MCP (iOS only)
│   │   ├── BundledCatalogStore/     # CatalogStore: DBs shipped as app resources         [future]
│   │   ├── DownloadableCatalogStore/# CatalogStore: fetch + cache DBs on first run        [future]
│   │   ├── MarkdownRendering/       # markdown string -> display models
│   │   ├── SearchFeature/ ...       # @Observable view models (depend on BackendAPI only)
│   │   # --- UI packages: SIX fully-native variants, one per idiom x framework ---
│   │   #     (each imports only its own framework; no bridges; binds shared view models)
│   │   ├── ShellMacAppKit/    ShellMacSwiftUI/      # macOS  (AppKit, SwiftUI)
│   │   ├── ShelliPhoneUIKit/  ShelliPhoneSwiftUI/   # iPhone (UIKit, SwiftUI)  -- distinct from iPad
│   │   ├── ShelliPadUIKit/    ShelliPadSwiftUI/     # iPad   (UIKit, SwiftUI)  -- distinct from iPhone
│   │   └── <Feature> screens per variant            # each variant brings its own native screens
│   │   # --- Impl / composition packages (wire concretes together) ---
│   │   ├── MacBackendImpl/          # LocalSubprocessBackend over SubprocessTransport (macOS)
│   │   └── LocalEmbeddedBackendImpl/     # LocalEmbeddedBackend + CatalogStore (iOS)                  [future]
│   └── Tests/
├── Apps/                            # SIX app targets, one per UI variant; iPhone and iPad are SEPARATE
│   ├── CupertinoMacAppKit/          # macOS AppKit    (ShellMacAppKit     + MacBackendImpl)
│   ├── CupertinoMacSwiftUI/         # macOS SwiftUI   (ShellMacSwiftUI    + MacBackendImpl)
│   ├── CupertinoiPhoneUIKit/        # iPhone UIKit    (ShelliPhoneUIKit   + LocalEmbeddedBackendImpl)  [future]
│   ├── CupertinoiPhoneSwiftUI/      # iPhone SwiftUI  (ShelliPhoneSwiftUI + LocalEmbeddedBackendImpl)  [future]
│   ├── CupertinoiPadUIKit/          # iPad UIKit      (ShelliPadUIKit     + LocalEmbeddedBackendImpl)  [future]
│   └── CupertinoiPadSwiftUI/        # iPad SwiftUI    (ShelliPadSwiftUI   + LocalEmbeddedBackendImpl)  [future]
└── docs/
    └── DESIGN.md
```

> M0 status: the two macOS variants exist today, currently named `CupertinoDesktopSwiftUI` / `CupertinoDesktopAppKit` (= the `macSwiftUI` / `macAppKit` variants) over `ShellSwiftUI` / `ShellAppKit`. The rename to the idiom scheme above and the four iOS variants are future work (sections 5.3, 13).

Dependency direction is strictly one-way: **Foundation → Infrastructure → Features → UI → Apps**. Each app depends on exactly one UI variant package plus one backend `*Impl`; UI packages depend on Features/Core; nothing depends on Apps. The six UI variants share one set of view models, so iPhone-vs-iPad and UIKit-vs-SwiftUI differences are purely presentational.

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

### UI layer (six parallel, fully native variants)

The UI ships as **six parallel packages, one per idiom x framework, each implementing the same functionality and consumed through same-shaped protocols**. None fakes another: there is no `NSHostingController`, no `UIHostingController`, no representable bridge. Each package imports only its own framework and vends a real native root.

The matrix (idiom is a first-class axis: iPhone and iPad are deliberately different, not one size-class-adaptive shell):

| Variant | Framework | Vends | Idiom notes |
|---|---|---|---|
| `ShellMacAppKit` | AppKit | `NSViewController` | macOS window chrome, menus |
| `ShellMacSwiftUI` | SwiftUI | `some View` | macOS `WindowGroup` |
| `ShelliPhoneUIKit` | UIKit | `UIViewController` | compact: tab/stack navigation |
| `ShelliPhoneSwiftUI` | SwiftUI | `some View` | compact layout |
| `ShelliPadUIKit` | UIKit | `UIViewController` | regular: `UISplitViewController`, multi-column |
| `ShelliPadSwiftUI` | SwiftUI | `some View` | regular: `NavigationSplitView`, multi-column |

Each exposes the same-named `UI.RootExperience` (parallel protocols, idiomatic per framework: `some View` vs `UIViewController` vs `NSViewController`), not one erased type, so none pays a hosting/erasure penalty. The shared, framework-agnostic seam (`UI.RootModel` and the per-feature view models in `AppCore`/Features) is bound identically by all six, so **iPhone-vs-iPad and UIKit-vs-SwiftUI differences live entirely in the view code, never in logic.**

### Apps layer

There are **six app targets, one per UI variant** (iPhone and iPad are separate targets, per the design): `CupertinoMacAppKit`, `CupertinoMacSwiftUI`, `CupertinoiPhoneUIKit`, `CupertinoiPhoneSwiftUI`, `CupertinoiPadUIKit`, `CupertinoiPadSwiftUI`. Each is a pure composition + framework-specific entry point: it links exactly one UI variant package and one backend `*Impl`, and mounts `UI.LiveRootExperience().makeRoot(model:)`. macOS targets use `MacBackendImpl` (the local-subprocess/brew-binary route); iOS targets use `LocalEmbeddedBackendImpl`. All logic is in Features; all views are in the UI packages.

## 5. The backend seam and its conformers

There is exactly **one universal seam**: `Backend.Documentation`. Features and UI depend on it and nothing else. Conformers are named by **locality** (local vs remote), never by protocol. **MCP is not a conformer and not universal**: it is only the wire one conformer's *client* happens to speak. The first-order split is local (today) vs remote (future):

```
Features / UI
     │  depends only on
     ▼
Backend.Documentation         (BackendAPI)   domain verbs, returns AppModels
     ├── Backend.LocalSubprocess  (macOS): out-of-process on THIS machine. Talks to the
     │        local `cupertino serve` (the brew binary, by design) via its MCP client
     │        (MCPClientKit) over a SubprocessTransport. MCP lives only on that client.
     ├── Backend.LocalEmbedded    (iOS only): in-process. Calls cupertino's read APIs
     │        directly. No MCP, no JSON-RPC, no transport. Typed results.
     └── Backend.Remote           (future): out-of-process, remote (network). Not built.
```

The conformers are independent and have nothing in common below `Backend.Documentation`. Locality is the axis: a remote backend is a new sibling here, not a transport swapped inside the local one; it does not touch the local conformers. The embedded path's fidelity is *higher* (typed results, no markdown round-trip), but it is **iOS-only** by design: the macOS app exists to drive the real brew binary, so it stays on the subprocess path.

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

**Embedded is mobile-only.** iOS cannot spawn a subprocess, so there is no `cupertino serve` to talk to; the only way to read the corpus is in-process. (And the desktop deliberately does *not* use this path: the macOS app's purpose is to exercise the real Homebrew binary over the subprocess, section 5.2, so embedding there would defeat the point.) The honest answer for iOS is **not** to run an in-process MCP server and talk to ourselves over a fake channel; it is to call cupertino's read APIs directly. `LocalEmbeddedBackend` conforms `Backend.Documentation` by calling the same services `cupertino serve` calls (`Services.ReadService`, `Search.Index`, `Sample.Index`, the production source registry), opening the SQLite DBs through a `CatalogStore` (section 5.5), and mapping cupertino's typed results into `AppModels`. No MCP, no JSON-RPC, no transport.

**Hard upstream constraint**: cupertino's read targets are macOS-only today (`platforms: [.macOS(.v13)]`, `#if os(macOS)`, `FileManager.homeDirectoryForCurrentUser`). So `LocalEmbeddedBackend` is **not buildable for iOS** against cupertino as it stands. Per the maintainer's call ("most correct and highest fidelity, extremely refactored"), the plan is the proper upstream refactor in the cupertino repo: add the `.iOS` platform, split the read path cleanly from the macOS-only crawler/indexer/WebKit producers, and resolve all paths through injection (`Shared.Paths` is already path-DI). This is real cross-repo work (milestone M7), landing before the M8 iOS apps, not a local shim.

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
- **`LocalEmbeddedBackend` (iOS only)**: no process and no transport. "Connect" means resolving the corpus via `CatalogStore` and opening the SQLite DBs; failure is a missing/locked/old corpus (first-run download or bundled-corpus error). Startup cost is opening the DBs, not spawning.

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

## 11. Why six parallel apps share one backend

The compare plan works only if the comparison is fair: identical backend, identical models, identical features, with the **only** variables being device idiom and UI framework. The seam layering guarantees that. macOS runs AppKit and SwiftUI side by side over `MacBackendImpl` (the local-subprocess/brew-binary route); iPhone and iPad each run UIKit and SwiftUI over `LocalEmbeddedBackendImpl`. That is six fully-native variants over one set of view models. iPhone and iPad are deliberately different presentations of the *same* models, not a single adaptive shell, so the design can compare real per-idiom UIs. When decisions are made, losing `Apps/` targets are deleted and nothing else changes. A future remote backend touches one concrete package plus one Impl, never a feature or a view.

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
- **M2 (Read path)**: framework browser → doc reader rendering `read_document` markdown in both macOS variants.
- **M3 (Search)**: debounced `search_docs` with scopes; result rows navigate to reader.
- **M4 (Samples)**: `list_samples` → `read_sample` tree → `read_sample_file` code viewer.
- **M5 (Symbols & polish)**: `get_inheritance` / conformances related panel; connection-status UX, empty/first-run states, error handling.
- **M6 (Compare & decide, macOS)**: evaluate `macAppKit` vs `macSwiftUI` over the same `MacBackendImpl`, pick one or keep both, delete any losing target.
- **M7 (iOS embedding, gated on upstream)**: land the cupertino iOS-buildability refactor (section 5.3) so `LocalEmbeddedBackend` builds for iOS, and add the `CatalogStore` conformers. (There is **no** macOS-embedded path: embedded is mobile-only; the macOS app stays on the brew-binary subprocess by design.)
- **M8 (iOS apps)**: ship the four iOS variants over `LocalEmbeddedBackendImpl` as distinct targets: `CupertinoiPhoneUIKit`, `CupertinoiPhoneSwiftUI`, `CupertinoiPadUIKit`, `CupertinoiPadSwiftUI`. iPhone and iPad are deliberately different UIs over the shared view models; compare UIKit vs SwiftUI on each idiom.
- **M9 (Remote, optional)**: a `Backend.Remote` conformer (HTTP/SSE to a hosted cupertino) for a shared-corpus deployment, if a use case appears. A sibling backend, not a transport inside the local one.
