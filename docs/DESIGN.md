# Cupertino Desktop: Architecture & Design

Status: **canonical.** This is the project's design of record, not a draft. Changes are deliberate amendments to canon, not exploration. Targets the cupertino backend as it exists on `cupertino@develop`.

## 1. Goals & non-goals

**Goals**

- Native UI showcase for browsing Apple developer docs, Swift Evolution, and sample code offline. The fixed matrix is macOS SwiftUI/AppKit, iPhone SwiftUI/UIKit, iPad SwiftUI/UIKit, Linux Qt, and Windows Qt.
- Be a thin client over the `cupertino` corpus, reached through one backend seam with several implementations. Do **not** reimplement search, indexing, or storage. We are **not** "an MCP app": MCP is merely the wire that one local adapter happens to speak to a `cupertino serve` subprocess (section 5), one option among several, not the system's identity.
- **THE LAW: cupertino is reached only through our own protocol, never by direct calls.** We define a backend protocol shaped for *us* (clean, typed, digestible), and cupertino is a backend behind it. Every local strategy for reaching cupertino, subprocess or **embedded**, is an **adapter** that implements that protocol. Cupertino's types and functions appear **only inside an adapter**, and even the in-process embedded path is an adapter, not a license to call cupertino directly. Nothing above the adapter, no feature, no view, no view model, ever imports or references anything from cupertino. Only protocol calls.
- There is **no remote backend**. Everything is local, in two flavors: **macOS talks to a local `cupertino serve` subprocess over MCP** (deliberately, to exercise the real Homebrew-installed binary), and **iPhone/iPad/Linux/Windows adapt cupertino's read path in-process** over an installed catalog that only Cupertino-owned code opens. MCP exists only on macOS.
- **This project is also a public demonstration.** Building the *same* app as eight fully-native UI variants across five idiom/platform surfaces (macOS, iPhone, iPad, Linux, Windows) and four frameworks (SwiftUI, AppKit, UIKit, Qt) over one shared core is a deliberate showcase of clean architecture, per-idiom UI differences, and framework trade-offs. The variants and their differences are a feature to exhibit, not just an internal convenience. Treat the code accordingly: it will be read as an example.
- Ship **eight fully-native UI variants** over one shared set of view models, differing by device idiom/platform and framework, never by logic: **macAppKit, macSwiftUI, iPhoneUIKit, iPhoneSwiftUI, iPadUIKit, iPadSwiftUI, LinuxQt, WindowsQt**. iPhone and iPad are *distinct* UIs (not one size-class-adaptive shell). No hosting shortcuts: each shell uses its own native framework and vends a real native root. All eight bind the identical `UI.RootModel` + feature view models and the identical backend seam.
- Follow the ExtremePackaging monorepo convention: `Main.xcworkspace` at root, single `Package.swift` in `Packages/`, app targets in `Apps/`, layered packages. Every package depends only on protocol (seam) packages; concrete packages never import each other; `*Impl` packages are the only place concretes are composed.

**Non-goals**

- No crawling or index building in this app. The cupertino server (subprocess on macOS) or embedded read engine (iPhone/iPad/Linux/Windows) owns search and storage. Embedded targets may download a prebuilt Cupertino corpus, but they do not build indexes or open storage directly.
- No re-parsing of HTML or building a second search index.
- No remote backend or remote UI.
- No visionOS/watchOS targets yet (the layering keeps that door open).

## 2. Backend reality (what we actually build against)

There are, from first principles, two local ways to reach cupertino: **in-process** (embedded read engine, no MCP) and **out-of-process on this machine** (a `cupertino serve` subprocess). Only macOS uses the out-of-process path, and the one cupertino exposes to a separate process is MCP (JSON-RPC tools): send a request, get a mostly markdown string back. So MCP is real, but it is a property of *one mechanism of one adapter*, not of the system.

What the subprocess path needs, and where it comes from:

- **The MCP client lives in [`SwiftMCPClient`](https://github.com/mihaelamj/SwiftMCPClient)** (an external public package, the client extracted from this repo). It carries an `MCPClient` that speaks JSON-RPC over an injected `Transport.Channel`, layered over [`SwiftMCPCore`](https://github.com/mihaelamj/SwiftMCPCore), the neutral Foundation-only MCP wire types (`Request`, `CallToolResult`, `Tool`, `Resource`, ... under the `MCP.Core.Protocols.*` namespace, wire-compatible with cupertino). The subprocess adapter depends only on `SwiftMCPClient`'s `Client.MCP` seam, so it never imports cupertino at all.
- **cupertino's `MCP.Client`** (the upstream client `actor`) is **stdio-hardcoded**: it constructs a `Process` directly with no transport injection point, so we do **not** build on it. `SwiftMCPClient` keeps the subprocess protocol concerns outside the UI and outside `LocalSubprocessBackend` tests.
- **cupertino's read services, search, indexing, and storage** are external to this repo. The app does not depend on the `cupertino` repository or a symlink for embedded mode; it consumes tagged `CupertinoDataKit` and `CupertinoDataEngine` packages. The subprocess path continues to use the installed `cupertino serve` binary.

### 2.1 Connection lifecycle (our client, transport-agnostic)

```swift
// All from SwiftMCPClient.
let transport: any Transport.Channel = Transport.Subprocess(command: "cupertino", arguments: ["serve"])
let client = MCPClient(transport: transport)
try await client.connect()    // transport.start() + MCP `initialize` handshake
// ... callTool / readResource ...
await client.disconnect()      // transport.stop()
```

`connect()` starts the transport (which, for the subprocess transport, launches the process and wires its pipes) and performs the MCP `initialize` handshake. This client and its transports (from `SwiftMCPClient`) are used **only** by the macOS local-subprocess adapter (section 5.2); the embedded adapter does not use them at all.

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

### 2.4 cupertino's actual surface (what an adapter maps from)

Two surfaces exist, and the two adapters map from different ones:

**(a) The MCP tool catalog** (what `cupertino serve` exposes to a separate process; the *subprocess* adapter's source). Roughly seventeen tools (from `CompositeToolProvider`):

`search`, `search_docs`, `search_samples`, `search_packages`, `search_hig`, `search_all`, `list_frameworks`, `read_document`, `list_samples`, `read_sample`, `read_sample_file`, `search_symbols`, `search_property_wrappers`, `search_concurrency`, `get_inheritance`, `search_conformances`, `search_generics`.

Output is **mostly markdown**: handlers run typed results through `Services.Formatter.Markdown` (and friends) before returning. `read_document` can emit **JSON** (`format: json|markdown`); most search tools return markdown only. So the subprocess adapter mostly parses markdown into `AppModels`, requesting JSON where a tool offers it.

**(b) The in-process typed services** (what `cupertino serve` calls *before* formatting; the *embedded* adapter's source): `UnifiedSearchService`, `DocsSearchService`, `HIGSearchService`, `PackageIndex`, `ReadService`, `TeaserService`. These return typed results, so the embedded adapter maps types to `AppModels` with no markdown round-trip.

Both surfaces are cupertino's, and both are touched **only** inside their respective adapter (§5). Our protocol (§5.1) is shaped for us and is unaware either exists.

### 2.5 The string penalty is an adapter concern, not the architecture's

The MCP tool surface mostly returns **formatted markdown strings, not typed models**. That is real, but it is **contained inside the subprocess adapter** and never leaks: above the protocol, everything is `AppModels`. So:

1. `read_document` markdown is carried through as the page body and rendered natively (a feature, not a bug, for the reader).
2. For list/tree UIs (frameworks, search rows, sample trees) the subprocess adapter parses markdown (or decodes JSON where offered) into `AppModels`; the embedded adapter skips this entirely by mapping typed services. A spike in milestone M1 (§13) records, per tool, whether JSON is available so the subprocess adapter decodes rather than scrapes. Either way, the cost lives in one adapter.

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
│   │   ├── CatalogStoreAPI/         # CatalogStore protocol and catalog install state
│   │   ├── AppCore/             # UI namespace + framework-agnostic RootModel
│   │   ├── PresentationBridge/  # framework-neutral presentation state, trees, stable IDs
│   │   #   (the MCP client, its Transport.Channel seam, and the subprocess transport
│   │   #    are NOT local: they live in the external SwiftMCPClient package,
│   │   #    consumed via a versioned SPM dependency. They are used only by macOS.)
│   │   # --- Concrete packages (depend only on API packages) ---
│   │   ├── LocalSubprocessBackend/              # Documentation adapter; talks to local `cupertino serve` via the kit's Client.MCP seam; maps -> AppModels (macOS)
│   │   ├── LocalEmbeddedBackend/         # Documentation adapter via in-process cupertino read engine; no MCP (iPhone/iPad/Linux/Windows)
│   │   ├── DevelopmentCatalogStore/ # CatalogStore: local mobile dev catalog             [current]
│   │   ├── DownloadedCatalogStore/  # CatalogStore: install free mobile catalog           [future]
│   │   ├── MarkdownRendering/       # markdown string -> display models
│   │   ├── SearchFeature/ ...       # @Observable view models (depend on BackendAPI + PresentationBridge)
│   │   # --- UI packages: eight fully-native variants, one per idiom/platform x framework ---
│   │   #     (each imports only its own framework; no bridges; binds shared view models)
│   │   ├── ShellMacAppKit/    ShellMacSwiftUI/      # macOS  (AppKit, SwiftUI)
│   │   ├── ShelliPhoneUIKit/  ShelliPhoneSwiftUI/   # iPhone (UIKit, SwiftUI)  -- distinct from iPad
│   │   ├── ShelliPadUIKit/    ShelliPadSwiftUI/     # iPad   (UIKit, SwiftUI)  -- distinct from iPhone
│   │   ├── ShellLinuxQt/   ShellWindowsQt/       # Desktop Qt (Linux, Windows)
│   │   └── <Feature> screens per variant         # each variant brings its own native screens
│   │   # --- Impl / composition packages (wire concretes together) ---
│   │   ├── MacBackendImpl/          # Backend.LocalSubprocess over the kit's Transport.Subprocess (macOS)
│   │   └── LocalEmbeddedBackendImpl/     # LocalEmbeddedBackend + CatalogStore (iPhone/iPad/Linux/Windows) [future]
│   └── Tests/
├── Apps/                            # eight app targets, one per UI variant; iPhone and iPad are SEPARATE
│   ├── CupertinoMacAppKit/          # macOS AppKit    (ShellMacAppKit     + MacBackendImpl)
│   ├── CupertinoMacSwiftUI/         # macOS SwiftUI   (ShellMacSwiftUI    + MacBackendImpl)
│   ├── CupertinoiPhoneUIKit/        # iPhone UIKit    (ShelliPhoneUIKit   + LocalEmbeddedBackendImpl)  [future]
│   ├── CupertinoiPhoneSwiftUI/      # iPhone SwiftUI  (ShelliPhoneSwiftUI + LocalEmbeddedBackendImpl)  [future]
│   ├── CupertinoiPadUIKit/          # iPad UIKit      (ShelliPadUIKit     + LocalEmbeddedBackendImpl)  [future]
│   ├── CupertinoiPadSwiftUI/        # iPad SwiftUI    (ShelliPadSwiftUI   + LocalEmbeddedBackendImpl)  [future]
│   ├── CupertinoLinuxQt/            # Linux Qt        (ShellLinuxQt       + LocalEmbeddedBackendImpl)  [future]
│   └── CupertinoWindowsQt/          # Windows Qt      (ShellWindowsQt     + LocalEmbeddedBackendImpl)  [future]
└── docs/
    └── DESIGN.md
```

> Status: four Apple app variants exist today, the two macOS apps `CupertinoDesktopSwiftUI` / `CupertinoDesktopAppKit` (over `ShellSwiftUI` / `ShellAppKit`) and two adaptive mobile apps `CupertinoMobileSwiftUI` / `CupertinoMobileUIKit` (over `ShellSwiftUI` / `ShellUIKit`, each handling both iPhone and iPad rather than splitting per device). The framework browser, document reader, and search ship in all of them; macOS runs the live `Backend.LocalSubprocess` over `cupertino serve`, and the mobile apps run `Backend.LocalEmbedded` over the no-corpus mock path by default. The mobile app targets can opt into `Catalog.DevelopmentStore` for a local installed catalog while the real mobile catalog installer remains future work. The embedded adapter can consume CupertinoDataKit document, sample, symbol, and package reader slices, `MobileBackendImpl` can inject the published `CupertinoDataEngine` facade, `CatalogStoreAPI` resolves opaque corpus handles for embedded composition, and the live real-corpus smoke passes against `~/.cupertino`. The rename to the idiom scheme above, the per-device split, Linux/Windows Qt, and app packaging remain future work (sections 5.3, 13).

Dependency direction is strictly one-way: **Foundation -> Infrastructure -> Features -> UI -> Apps**. Each app depends on exactly one UI variant package plus one backend `*Impl`; UI packages depend on Features/Core; nothing depends on Apps. The eight UI variants share one set of presentation values and view models, so iPhone-vs-iPad, UIKit-vs-SwiftUI, AppKit-vs-SwiftUI, Qt-vs-Apple, and Linux-vs-Windows Qt differences are purely presentational.

Types are namespaced under short per-module semantic anchors (`Model`, `Backend`, `Feature`, `UI`, `Markdown`); there is no project-name root prefix, since the Swift module already namespaces each target. So a type reads `UI.RootModel`, `Backend.LocalSubprocess`, `Feature.Search`.

## 4. Package architecture

### Foundation layer

- **`AppModels`**: pure value types: `Framework`, `DocPage`, `SearchHit`, `SampleProject`, `SampleFile`, `SymbolHit`, `DocURI`. `Sendable`, no dependencies. Make impossible states unrepresentable (e.g. `DocURI` is a validated wrapper, not a bare `String`).
- **`AppCore`**: shared protocols and errors: `DocumentationBackend` protocol (the seam, §5), `BackendError`, paging types.
- **`PresentationBridge`**: framework-neutral presentation values shared by feature
  view models and concrete shells. It owns state machines, logical trees, stable
  identifiers, and other data the shells can reify natively. It never owns widgets,
  navigation controllers, delegates, or rendering lifecycle.

### Infrastructure layer

- **`LocalSubprocessBackend`**: the macOS subprocess adapter. Implements `Backend.Documentation` by calling `SwiftMCPClient`'s `Client.MCP` seam and mapping the (mostly markdown) tool results into `AppModels`. It depends on the **seam**, not the concrete client, so it is testable with a fake and **imports no MCP wire types and no `cupertino` code at all.** The subprocess lifecycle, connection state, and JSON-RPC framing live in `SwiftMCPClient`; this adapter owns only the cupertino-tool-output to `AppModels` mapping. Everything above it sees the `Backend.Documentation` protocol.
- **`MarkdownRendering`**: converts server markdown strings to display models (AttributedString for SwiftUI, NSAttributedString for AppKit). Shared by both apps.

### Features layer (UI-framework-agnostic view models)

Each feature ships an `@Observable` view model that depends only on `DocumentationBackend` and the value types. It imports no UI framework (Observation only), so both UI packages bind to the exact same instance.

- **`SearchFeature`**: query box, result list, scopes (docs / samples / symbols).
- **`FrameworkBrowserFeature`**: sidebar of frameworks (`list_frameworks`), drill into a framework's pages.
- **`DocReaderFeature`**: render a `read_document` page, in-page nav, related symbols (`get_inheritance`, `search_conformances`).
- **`SampleBrowserFeature`**: `list_samples`, `read_sample` (project tree), `read_sample_file` (syntax-highlighted file viewer).

### UI layer (eight parallel, fully native variants)

The UI ships as **eight parallel packages, one per idiom/platform x framework, each implementing the same functionality and consumed through same-shaped protocols**. None fakes another: there is no `NSHostingController`, no `UIHostingController`, no representable bridge, no web stand-in for Qt, and no remote UI. Each package imports only its own framework and vends a real native root.

The matrix (idiom is a first-class axis: iPhone and iPad are deliberately different, not one size-class-adaptive shell):

| Variant | Framework | Vends | Idiom notes |
|---|---|---|---|
| `ShellMacAppKit` | AppKit | `NSViewController` | macOS window chrome, menus |
| `ShellMacSwiftUI` | SwiftUI | `some View` | macOS `WindowGroup` |
| `ShelliPhoneUIKit` | UIKit | `UIViewController` | compact: tab/stack navigation |
| `ShelliPhoneSwiftUI` | SwiftUI | `some View` | compact layout |
| `ShelliPadUIKit` | UIKit | `UIViewController` | regular: `UISplitViewController`, multi-column |
| `ShelliPadSwiftUI` | SwiftUI | `some View` | regular: `NavigationSplitView`, multi-column |
| `ShellLinuxQt` | Qt | `QMainWindow` | native Linux Qt model/view shell |
| `ShellWindowsQt` | Qt | `QMainWindow` | native Windows Qt model/view shell |

Each exposes the same-named `UI.RootExperience` or framework-equivalent root factory (parallel protocols, idiomatic per framework: `some View` vs `UIViewController` vs `NSViewController` vs `QMainWindow`), not one erased type, so none pays a hosting/erasure penalty. The shared, framework-agnostic seam (`UI.RootModel` and the per-feature view models in `AppCore`/Features) is bound identically by all eight, so **iPhone-vs-iPad, UIKit-vs-SwiftUI, AppKit-vs-SwiftUI, Qt-vs-Apple, and Linux-vs-Windows Qt differences live entirely in the view code, never in logic.**

#### Building the variants in parallel is a seam-discovery method, not a speed play

When we build a feature, we implement it in **two variants at once on purpose** (for example `ShellMacSwiftUI` and `ShellMacAppKit` over the same model). This is **slower** than doing one, and that is accepted: the point is not throughput, it is to **let the right shared abstraction reveal itself** instead of guessing it up front.

The genuine seam, which view-model shape, which protocol, which value type belongs in `AppCore`/Features versus inside each shell, is only knowable at the **second real consumer**. So we surface that second consumer deliberately:

1. Start each feature with a **deliberately thin** shared view model (`Feature.<Name>.Model` in its Features package): just the state and intents both frameworks obviously need.
2. Implement the feature in **two variants** against that model, writing each shell **idiomatically** (SwiftUI bindings; AppKit `withObservationTracking` driving `NSView`), never bending one to match the other.
3. **Reconcile**: whatever both shells end up expressing identically is real shared logic and is lifted into the view model (or a seam); whatever differs is presentation and **stays in the view code**.
4. Lift only the **proven** duplication into `AppCore` / Features / `SharedProtocols`, then continue to the next feature.

This is the operational form of the project's **"do not pre-abstract; abstract only at the second real consumer"** rule (see [rules/shared-protocols.md](rules/shared-protocols.md)): the parallel build **is** that second consumer, produced on purpose rather than imagined. The guard against false sharing: a candidate seam that fits SwiftUI's `some View` but forces AppKit, UIKit, or Qt into an unnatural shape is the **wrong** seam; if a proposed abstraction makes any shell less idiomatic, it does not belong in the shared layer, it belongs in the shells. The eight-variant matrix exists precisely so this pressure-test has more than one angle.

### Apps layer

There are **eight app targets, one per UI variant** (iPhone and iPad are separate targets, per the design): `CupertinoMacAppKit`, `CupertinoMacSwiftUI`, `CupertinoiPhoneUIKit`, `CupertinoiPhoneSwiftUI`, `CupertinoiPadUIKit`, `CupertinoiPadSwiftUI`, `CupertinoLinuxQt`, `CupertinoWindowsQt`. Each is a pure composition + framework-specific entry point: it links exactly one UI variant package and one backend `*Impl`, and mounts the shell root experience. macOS targets use `MacBackendImpl` (the local-subprocess/brew-binary route); iPhone/iPad/Linux/Windows targets use `LocalEmbeddedBackendImpl`. All logic is in Features; all views are in the UI packages.

## 5. The protocol and its adapters

There is exactly **one protocol**: `Backend.Documentation`, designed by us and for us (domain verbs, `AppModels` types). Features and UI make **only protocol calls** and depend on nothing else. Cupertino is a backend behind that protocol, reached **only** through **adapters**, one per local strategy. An adapter is the **sole** place cupertino is referenced; nothing above it imports cupertino, and that includes the embedded path. Adapters are named by locality/mechanism, never by protocol. **MCP is not an adapter and not universal**: it is only the wire the macOS adapter's *client* happens to speak.

```
Features / UI
     │  make ONLY protocol calls; never see cupertino
     ▼
Backend.Documentation         (BackendAPI)   OUR protocol: domain verbs, AppModels
     │  implemented per transport strategy by adapters (the ONLY place cupertino is touched)
     ├── Backend.LocalSubprocess  (macOS only): out-of-process on THIS machine. Adapts the
     │        local `cupertino serve` (the brew binary, by design) via the kit's
     │        MCPClient over a Transport.Subprocess. Maps mostly-markdown -> AppModels.
     └── Backend.LocalEmbedded    (iPhone/iPad/Linux/Windows): in-process. Adapts cupertino's
              typed read services / extracted read engine -> AppModels. No MCP,
              no transport. Higher fidelity, but still an adapter: cupertino stops here.
```

The adapters are independent and have nothing in common below `Backend.Documentation`.
The embedded adapter's fidelity is *higher* (typed results, no markdown round-trip),
but it is still an adapter: it maps cupertino's typed services to our protocol and is
the only place those services are named. The import contract enforces the law
mechanically: only adapter packages may depend on cupertino; the protocol, features,
view models, and UI cannot.

### 5.1 `Backend.Documentation` (our protocol)

We design this protocol, shaped for us: pure domain verbs, returning `AppModels` value types, never leaking MCP, JSON-RPC, or cupertino types. It is the only thing features and UI call, and the only contract adapters implement. The differences between adapters are invisible above it.

**The full contract is canonized in [docs/PROTOCOL.md](PROTOCOL.md)** and is the spec of record for `BackendAPI` + `AppModels`. In brief, it is composed by interface segregation from capability slices, so a feature depends only on what it uses:

- `Backend.Connecting` (lifecycle), `Backend.FrameworkBrowsing`, `Backend.DocumentReading`
- `Backend.Searching` (result-faithful: `searchDocs -> [DocHit]`, `searchSamples -> SampleResults`, `searchPackages -> [PackageHit]`, `searchEverything -> UnifiedResults`; we do not flatten distinct natures into one list)
- `Backend.SampleBrowsing`, `Backend.CodeIntelligence` (symbols, conformances, property wrappers, concurrency, generics, inheritance)
- `Backend.Documentation` = the composition of all of the above; one adapter implements it because one cupertino answers all of it.

Registered as a Point-Free `DependencyKey` so features inject it uniformly and tests swap a fake:

```swift
extension DependencyValues {
    var backend: any Backend.Documentation { ... } // live = the Impl's adapter, test = FakeBackend()
}
```

`DocPage` carries structured fields plus the raw markdown body so `DocReaderFeature` renders without re-fetching. See [docs/PROTOCOL.md](PROTOCOL.md) §2 for every value type and §4 for the adapter mapping.

### 5.2 Adapter A: `LocalSubprocessBackend` (local, out-of-process)

This is the adapter that speaks MCP, because the only thing `cupertino serve` exposes to a separate process is the MCP JSON-RPC tool surface. It maps the (mostly markdown) tool results into `AppModels` per the strategy table in section 6. MCP lives entirely inside the external package it uses; nothing above the protocol sees it.

The MCP machinery is the external **`SwiftMCPClient`**: an `MCPClient` `actor` that speaks JSON-RPC over an injected `Transport.Channel`, the channel seam itself, and a macOS subprocess channel. Its wire types come from **`SwiftMCPCore`** (the neutral Foundation-only MCP protocol types under `MCP.Core.Protocols.*`, wire-compatible with cupertino, so we do not re-invent JSON-RPC), and the client deliberately does **not** build on cupertino's stdio-hardcoded `MCP.Client`. `LocalSubprocessBackend` depends only on `SwiftMCPClient`'s `Client.MCP` seam; the transport is the only swap point:

```swift
// SwiftMCPTransport (in SwiftMCPClient): the byte-frame channel seam, carries no MCP types
public extension Transport {
    protocol Channel: Sendable {
        func start() async throws
        func stop() async
        func send(_ frame: Data) async throws        // one JSON-RPC frame
        var inbound: AsyncThrowingStream<Data, Error> { get }
    }
}
```

- **`Transport.Subprocess`** (`SwiftMCPSubprocessTransport`, macOS): spawns `cupertino serve`, wires stdin/stdout, newline-delimited frames. The macOS production path today.

### 5.3 Adapter B: `LocalEmbeddedBackend` (local, in-process)

**Embedded is the iPhone/iPad/Linux/Windows path.** These targets do not talk to Cupertino over
MCP and do not use a remote service. They run Cupertino's refactored read engine in process
over an installed catalog, and only that engine handles its storage. The macOS app
deliberately does *not* use this path: its purpose is to exercise the real Homebrew binary over the subprocess
(section 5.2), so embedding there would defeat the point. The honest answer for
embedded targets is **not** to run an in-process MCP server and talk to ourselves over a
fake channel. But "in-process" does **not** mean "call cupertino freely":
`LocalEmbeddedBackend` is still an **adapter behind our protocol**. It implements
`Backend.Documentation` by wrapping CupertinoDataKit reader slices supplied by the
composition root and mapping typed results into `AppModels`. Those cupertino services are
named **only here**, inside this one adapter; everything above it makes protocol calls and
never sees them. No MCP, no JSON-RPC, no transport, no database handles, and no leakage.

**Upstream constraint (precise).** The published `CupertinoDataEngine` package now supplies
the embedded read facade over Cupertino-owned readers. Desktop and mobile targets consume
that facade only through `MobileBackend.live(engine:)`, `MobileBackend.live(catalogStore:)`,
and `Backend.Documentation`; they never receive database file names, database handles,
schemas, or concrete reader types. The live packaged-corpus smoke against the current
release corpus now passes through `scripts/check-local-embedded-corpus.sh`. The remaining
app-side work is concrete catalog stores and per-platform app packaging.

### 5.4 Backend selection is itself by protocol

No package hard-codes which adapter it uses. The choice lives only in the `*Impl` composition packages, which an app target picks:

- **`MacBackendImpl`** = `Backend.LocalSubprocess(MCPClient(Transport.Subprocess(...)))`, wiring the kit's client and subprocess channel into the adapter.
- **`LocalEmbeddedBackendImpl`** = `MobileBackend.live(catalogStore:)` over `CupertinoDataEngine`, used by iPhone, iPad, Linux Qt, and Windows Qt once concrete catalog stores and app packaging are added.

### 5.5 Where the corpus lives on embedded targets (`CatalogStore`)

On macOS the corpus sits in the user's home directory, populated by `cupertino fetch`/`save`, and only the subprocess touches it. On iPhone and iPad, the app installs a free downloadable catalog for Cupertino's embedded engine. `LocalEmbeddedBackend` itself does not receive database file paths or open storage; it receives CupertinoDataKit reader protocols from the composition root. Linux and Windows will also stay behind the embedded backend seam, with concrete packaging decided separately from the mobile download path.

```swift
public enum Catalog {}

public extension Catalog {
    protocol Store: Sendable {
        func currentCorpus() async throws -> CorpusHandle
    }

    struct CorpusHandle: Sendable, Hashable {
        public let bundleURL: URL
    }
}
```

- **`DevelopmentCatalogStore`**: mobile dev-only local catalog resolver. Mobile apps opt in with `CUPERTINO_MOBILE_USE_DEV_CATALOG=1`, use `CUPERTINO_MOBILE_DEV_CATALOG` when set, and otherwise fall back under Application Support. The package smoke can still pass the legacy `CUPERTINO_DESKTOP_EMBEDDED_CORPUS` path. It returns only an opaque corpus handle and never inspects resource files.
- **`DownloadedCatalogStore`**: future mobile installer. On first run, install a free versioned catalog under Application Support and cache it; check for updates later. Smaller binary, refreshable catalog, at the cost of a first-run download.

Mobile apps do not bundle the corpus. The real installer remains the release gate before shipping mobile real-data UI.

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

Connection state is observable in either adapter (`ConnectionStatusBadge`): `idle -> connecting -> connected -> failed(reason)`. What "connect" means and how it fails differs by adapter:

- **`LocalSubprocessBackend` over `Transport.Subprocess` (macOS)**: owns one long-lived `MCPClient` (from the kit); the client `actor` serializes calls, so it adds no extra locking. Discover the `cupertino` executable (explicit path, then `PATH`); surface a clear "cupertino not found / docs not downloaded" empty state linking to install instructions rather than crashing. Reconnect on demand if the subprocess dies (a thrown client error on a call). Confirm App Sandbox entitlements permit spawning a subprocess, or ship non-sandboxed for the v1 dev tool.
- **`LocalEmbeddedBackend` (iPhone/iPad/Linux/Windows)**: no process, no MCP, and no transport. "Connect" is a no-op for the adapter because the composition root supplies already-constructed CupertinoDataKit readers; corpus resolution and storage opening belong to the Cupertino-owned embedded engine. Startup failures surface as missing, locked, old, or not-yet-downloaded corpus errors from that engine.

## 8. State & view-model design

- ViewModels are `@Observable` classes holding `@Dependency(\.backend)`, exposing async load methods and `LoadState<T>` (`idle / loading / loaded(T) / failed(Error)`). Make impossible states unrepresentable; never force-unwrap.
- SwiftUI views use `@Bindable` over the ViewModel. AppKit and UIKit controllers observe the same `@Observable` via `withObservationTracking` (or a small `Observations` bridge) to drive retained view updates. Qt adapts the same state into `QAbstractItemModel` / signals on the GUI thread.
- Navigation: a single `AppRoute` enum (`.search`, `.framework(id)`, `.document(uri)`, `.sample(id)`) drives every shell through its native navigation mechanism (`NavigationSplitView` / navigation stacks in SwiftUI, split controllers in AppKit/UIKit, and Qt actions/models).
- No UI shell may use a hosting shortcut to stand in for its native implementation. SwiftUI renders SwiftUI, AppKit renders AppKit, UIKit renders UIKit, and Qt renders Qt.

## 9. Concurrency

- Swift 6 strict concurrency. All models `Sendable`. Backend is an actor; ViewModels are `@MainActor`.
- All concrete UI updates run on the UI thread. SwiftUI abstracts much of that away, but UIKit, AppKit, and Qt make the rule explicit; embedded-engine callbacks marshal back before touching UI objects.
- Long calls (search, read) run as structured `Task`s owned by the ViewModel, cancelled on view disappearance / new query (debounce search input ~250ms).

## 10. Testing

- Swift Testing (`@Test`, `@Suite`, `#expect`), `withDependencies` to inject `FakeBackend`.
- `FakeBackend` returns fixture strings (capture real `cupertino serve` output once, store under `Packages/Tests/Fixtures/`) to test the parsers in `LocalSubprocessBackend` against real shapes.
- Each seam is independently fakeable: a fake `Client.MCP` feeds canned tool output to test `LocalSubprocessBackend`'s parsers (the kit separately tests `MCPClient` over a fake `Transport.Channel`); a fake `CatalogStore` feeds temp corpus URLs to test the embedded path. Concrete packages stay unit-testable in isolation because they import only protocols.
- Parameterized tests for the markdown/JSON parsers (`@Test(arguments:)`).
- No tests spawn the real subprocess except one opt-in integration smoke test, gated behind an env flag.

## 11. Why eight parallel apps share one backend

The showcase works only if the comparison is fair: identical backend seam, identical
models, identical features, with the **only** variables being device idiom/platform and
UI framework. The seam layering guarantees that. macOS runs AppKit and SwiftUI side by
side over `MacBackendImpl` (the local-subprocess/brew-binary route); iPhone and iPad
each run UIKit and SwiftUI over `LocalEmbeddedBackendImpl`; Linux and Windows run Qt
over `LocalEmbeddedBackendImpl`. That is eight fully-native variants over one set of view
models. iPhone and iPad are deliberately different presentations of the *same* models,
not a single adaptive shell, so the design can compare real per-idiom UIs. No losing
target is planned: the fixed framework matrix is the product showcase.

## 12. Open questions (decision log)

1. **JSON vs markdown per tool**: resolved by M1 spike; recorded in §6 table.
2. **Markdown renderer**: native `AttributedString(markdown:)` vs a richer parser (swift-markdown) for code blocks/tables. Lean native first; escalate only if doc fidelity is poor.
3. **App target form**: `.xcodeproj` per app vs SwiftPM executable app targets in the workspace. Default: `.xcodeproj` per app under `Apps/` (better for entitlements, sandboxing, signing) referencing the `Packages` manifest.
4. **macOS sandboxing**: the macOS app spawns a subprocess; confirm App Sandbox entitlements allow it, or ship non-sandboxed for v1 (dev tool). Decide before any distribution work.
5. **Pinning the dependencies**: `SwiftMCPClient` is consumed as a versioned SPM dependency (`from: "0.1.0"`, which transitively brings `SwiftMCPCore`). The embedded path consumes Cupertino-owned data contract/engine packages by version. Default: bump lower bounds only when adopting a new tag.
6. **Embedded upstream**: making cupertino's read-path targets iPhone/iPad/Linux/Windows-buildable (section 5.4) is a change in the *cupertino* repo, not here. Schedule that before committing to the real embedded apps.
7. **Catalog delivery**: mobile `DownloadedCatalogStore` (section 5.5). The app cannot bundle the corpus; the catalog is installed after app install.
8. **Qt language/runtime boundary**: choose the concrete binding shape for `ShellLinuxQt` / `ShellWindowsQt` when implementation starts. The boundary must keep Qt native and local-only; it may adapt shared state through a narrow C/C++ facade, but not through remote UI or MCP.

## 13. Milestones

- **M0 (Skeleton)**: `Main.xcworkspace`, `Packages/Package.swift` with empty layered targets, both macOS `Apps/` targets launching an empty `NavigationSplitView` / `NSSplitViewController`. Compiles, runs, does nothing.
- **M1 (Backend seam + spike)**: `BackendAPI`, the external `SwiftMCPClient` (`SwiftMCPTransport` / `SwiftMCPSubprocessTransport` / `SwiftMCPClient` / `SwiftMCPClientAPI`, over the neutral `SwiftMCPCore` wire types), `LocalSubprocessBackend` over its subprocess channel, `MacBackendImpl`, `FakeBackend`. Spike each tool to fill the §6 strategy table. First real call: `list_frameworks` into the sidebar. (Done: the MCP client was extracted to a neutral package and the subprocess path repointed onto `SwiftMCPClient`.)
- **M2 (Read path)**: framework browser -> doc reader rendering `read_document` markdown in both macOS variants.
- **M3 (Search)**: debounced `search_docs` with scopes; result rows navigate to reader.
- **M4 (Samples)**: `Backend.LocalEmbedded` already maps `Sample.Index.Reader`; next UI step is `list_samples` -> `read_sample` tree -> `read_sample_file` code viewer.
- **M5 (Symbols & polish)**: `Backend.LocalEmbedded` already maps `Search.SymbolReading`; next UI step is `get_inheritance` / conformances related panel, connection-status UX, empty/first-run states, error handling.
- **M6 (Compare & decide, macOS)**: evaluate `macAppKit` vs `macSwiftUI` over the same `MacBackendImpl`, pick one or keep both, delete any losing target.
- **M7 (Embedded engine)**: `CupertinoDataEngine` is published and `MobileBackendImpl` can inject it as the composed document/symbol facade for iPhone, iPad, Linux, and Windows. `CatalogStoreAPI` resolves opaque corpus handles for embedded composition, `DevelopmentCatalogStore` supports mobile local real-data app work, and the live real-corpus smoke passes against `~/.cupertino`. Remaining work is the real mobile catalog installer and app packaging. There is **no** macOS-embedded path: the macOS app stays on the brew-binary subprocess by design.
- **M8 (Split Apple mobile apps)**: ship the four iPhone/iPad variants over `LocalEmbeddedBackendImpl` as distinct targets: `CupertinoiPhoneUIKit`, `CupertinoiPhoneSwiftUI`, `CupertinoiPadUIKit`, `CupertinoiPadSwiftUI`. iPhone and iPad are deliberately different UIs over the shared view models.
- **M9 (Qt desktop apps)**: ship `CupertinoLinuxQt` over `ShellLinuxQt` and `CupertinoWindowsQt` over `ShellWindowsQt`, both using `LocalEmbeddedBackendImpl`. Qt is the native Linux/Windows UI and both apps are local-only over an installed Cupertino catalog.
