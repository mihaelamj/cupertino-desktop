# Cupertino Desktop: Architecture & Design

Status: design draft. Target the cupertino MCP backend as it exists on `cupertino@develop`.

## 1. Goals & non-goals

**Goals**

- Native macOS app (macOS 15+, Swift 6.2+, Xcode 16+) for browsing Apple developer docs, Swift Evolution, and sample code offline.
- Thin UI client over the existing `MCPClient` from the `cupertino` package. Do **not** reimplement search, indexing, or storage.
- Ship **two app targets in parallel** (SwiftUI and AppKit) sharing one backend so we can compare and decide later (per README).
- Follow the ExtremePackaging monorepo convention: `Main.xcworkspace` at root, single `Package.swift` in `Packages/`, app targets in `Apps/`, layered feature packages.

**Non-goals**

- No crawling, downloading, or index building in this app. The `cupertino serve` subprocess owns all of that.
- No re-parsing of HTML or building a second search index.
- No iOS/visionOS targets in v1 (the layering keeps that door open).

## 2. Backend reality (what we actually build against)

The `cupertino` package exposes `MCP.Client`, an `actor` that spawns `cupertino serve` as a subprocess and talks MCP over stdio (newline-delimited JSON).

### 2.1 Connection lifecycle

```swift
let client = MCP.Client.cupertino(executablePath: nil) // factory: serverArguments = ["serve"]
try await client.connect()                              // spawns Process, runs initialize handshake
// ... calls ...
client.disconnect()                                     // terminates the subprocess
```

`connect()` launches the process, wires stdin/stdout pipes, and performs the MCP `initialize` handshake. `isConnected`, `serverInfo`, `serverCapabilities`, `protocolVersion` are readable after connect.

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

```
cupertino-desktop/
├── Main.xcworkspace                 # opens Packages + both app projects
├── Packages/
│   ├── Package.swift                # single manifest, all library targets
│   ├── Sources/
│   │   ├── <Foundation layer>
│   │   ├── <Infrastructure layer>
│   │   ├── <Features layer>
│   │   └── <Components>
│   └── Tests/
├── Apps/
│   ├── CupertinoDesktopSwiftUI/     # SwiftUI app target (.xcodeproj or app target)
│   └── CupertinoDesktopAppKit/      # AppKit app target
└── docs/
    └── DESIGN.md
```

Dependency direction is strictly one-way: **Foundation → Infrastructure → Features → Apps**. Apps depend on Features; Features never depend on Apps. UI components live only in their Components package, never in feature/screen code (one component per file, conforming to the `Component` protocol).

## 4. Package architecture

### Foundation layer

- **`DesktopModels`**: pure value types: `Framework`, `DocPage`, `SearchHit`, `SampleProject`, `SampleFile`, `SymbolHit`, `DocURI`. `Sendable`, no dependencies. Make impossible states unrepresentable (e.g. `DocURI` is a validated wrapper, not a bare `String`).
- **`DesktopCore`**: shared protocols and errors: `DocumentationBackend` protocol (the seam, §5), `BackendError`, paging types.

### Infrastructure layer

- **`MCPBackend`**: the single adapter that depends on the `cupertino` package's `MCP.Client`. Implements `DocumentationBackend`. Owns subprocess lifecycle, connection state, retries, and the string→model parsing/JSON extraction. **This is the only module that imports `cupertino`.** Everything above it sees the `DocumentationBackend` protocol, never `MCP.Client`.
- **`MarkdownRendering`**: converts server markdown strings to display models (AttributedString for SwiftUI, NSAttributedString for AppKit). Shared by both apps.

### Features layer (UI-framework-agnostic logic + per-framework views)

Each feature ships an `@Observable` ViewModel that depends only on `DocumentationBackend` (injected via `@Dependency`), plus two thin view sets (SwiftUI + AppKit) that bind to the same ViewModel.

- **`SearchFeature`**: query box, result list, scopes (docs / samples / symbols).
- **`FrameworkBrowserFeature`**: sidebar of frameworks (`list_frameworks`), drill into a framework's pages.
- **`DocReaderFeature`**: render a `read_document` / `readDocumentation` page, in-page nav, related symbols (`get_inheritance`, `search_conformances`).
- **`SampleBrowserFeature`**: `list_samples`, `read_sample` (project tree), `read_sample_file` (syntax-highlighted file viewer).

### Components layer

- **`DesktopComponents`**: reusable UI atoms conforming to `Component`: `MarkdownView`, `CodeBlockView`, `FrameworkRow`, `SearchResultRow`, `ConnectionStatusBadge`, `EmptyStateView`. One component per file, filename = component name.

### Apps layer

- **`CupertinoDesktopSwiftUI`**: `@main` App, `WindowGroup`, `NavigationSplitView` shell, composition root wiring `@Dependency` values.
- **`CupertinoDesktopAppKit`**: `NSApplicationDelegate`, `NSWindow` with `NSSplitViewController`, same composition root values.

Both apps are pure composition + framework-specific shell. All logic is in Features.

## 5. The backend seam (`DocumentationBackend`)

The protocol both apps and all features depend on. Keeps `MCP.Client` out of the UI and makes it trivial to inject a fake in tests (Swift Testing + `withDependencies`).

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

Registered as a Point-Free `DependencyKey`:

```swift
extension DependencyValues {
    var backend: any DocumentationBackend { ... } // liveValue = MCPBackend(), testValue = FakeBackend()
}
```

`DocPage` carries the raw markdown plus parsed metadata so `DocReaderFeature` renders without re-fetching.

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

M1 spike (§13) records, per tool, whether the raw `CallToolResult` carries JSON (strategy B) or only markdown (strategy A parser in `MCPBackend`). No parsing logic leaks above `MCPBackend`.

## 7. Subprocess & connection management

- `MCPBackend` owns one long-lived `MCP.Client`. Connect lazily on first use or at app launch with a visible "connecting" state.
- **Executable discovery**: pass `executablePath` explicitly when known; otherwise rely on the factory's discovery, and surface a clear "cupertino not found / docs not downloaded" empty state with a link to install instructions (README §Requirements). First-run UX must not hard-crash when the binary or corpus is missing.
- **Lifecycle**: connect on `applicationDidFinishLaunching` / `.task` at the App root; `disconnect()` on termination. Reconnect on demand if the subprocess dies (detect via a thrown `ClientError` on a call).
- **Connection state** is observable (`ConnectionStatusBadge`): `idle → connecting → connected → failed(reason)`.
- Because `MCP.Client` is an `actor`, all calls are already serialized and `Sendable`-safe; `MCPBackend` adds no extra locking.

## 8. State & view-model design

- ViewModels are `@Observable` classes holding `@Dependency(\.backend)`, exposing async load methods and `LoadState<T>` (`idle / loading / loaded(T) / failed(Error)`). Make impossible states unrepresentable; never force-unwrap.
- SwiftUI views use `@Bindable` over the ViewModel. AppKit controllers observe the same `@Observable` via `withObservationTracking` (or a small `Observations` bridge) to drive `NSView` updates.
- Navigation: a single `AppRoute` enum (`.search`, `.framework(id)`, `.document(uri)`, `.sample(id)`) drives both shells (the `NavigationSplitView` path in SwiftUI, selection state in the AppKit split controller).

## 9. Concurrency

- Swift 6 strict concurrency. All models `Sendable`. Backend is an actor; ViewModels are `@MainActor`.
- Long calls (search, read) run as structured `Task`s owned by the ViewModel, cancelled on view disappearance / new query (debounce search input ~250ms).

## 10. Testing

- Swift Testing (`@Test`, `@Suite`, `#expect`), `withDependencies` to inject `FakeBackend`.
- `FakeBackend` returns fixture strings (capture real `cupertino serve` output once, store under `Packages/Tests/Fixtures/`) to test the parsers in `MCPBackend` against real shapes.
- Parameterized tests for the markdown/JSON parsers (`@Test(arguments:)`).
- No tests spawn the real subprocess except one opt-in integration smoke test, gated behind an env flag.

## 11. Why two apps share one backend

The README's compare-then-decide plan works only if the comparison is fair: identical backend, identical models, identical features, with the **only** variable being the UI framework. The layering guarantees that. When the decision is made, the losing `Apps/` target is deleted and nothing else changes.

## 12. Open questions (decision log)

1. **JSON vs markdown per tool**: resolved by M1 spike; recorded in §6 table.
2. **Markdown renderer**: native `AttributedString(markdown:)` vs a richer parser (swift-markdown) for code blocks/tables. Lean native first; escalate only if doc fidelity is poor.
3. **App target form**: `.xcodeproj` per app vs SwiftPM executable app targets in the workspace. Default: `.xcodeproj` per app under `Apps/` (better for entitlements, sandboxing, signing) referencing the `Packages` manifest.
4. **Sandboxing**: the app spawns a subprocess; confirm App Sandbox entitlements allow it, or ship non-sandboxed for v1 (dev tool). Decide before any distribution work.
5. **Pinning the cupertino dependency**: local path during dev vs tagged SPM release. Default: local path (`../cupertino`) until the desktop app stabilizes.

## 13. Milestones

- **M0 (Skeleton)**: `Main.xcworkspace`, `Packages/Package.swift` with empty layered targets, both `Apps/` targets launching an empty `NavigationSplitView` / `NSSplitViewController`. Compiles, runs, does nothing.
- **M1 (Backend seam + spike)**: `DocumentationBackend`, `MCPBackend` connecting to `cupertino serve`, `FakeBackend`. Spike each tool to fill the §6 strategy table. First real call: `list_frameworks` into the sidebar.
- **M2 (Read path)**: framework browser → doc reader rendering `read_document` markdown in both apps.
- **M3 (Search)**: debounced `search_docs` with scopes; result rows navigate to reader.
- **M4 (Samples)**: `list_samples` → `read_sample` tree → `read_sample_file` code viewer.
- **M5 (Symbols & polish)**: `get_inheritance` / conformances related panel; connection-status UX, empty/first-run states, error handling.
- **M6 (Compare & decide)**: evaluate SwiftUI vs AppKit, pick one, delete the other target.
