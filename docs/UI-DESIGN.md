# Cupertino Desktop: UI Design

How the app presents itself on each platform and device, and how every screen behaves
while the backend is working. The guiding constraint: the same feature view models and
the same `Backend.Documentation` seam drive every shell, so this document specifies the
**presentation** (layout, navigation idiom, state surfaces) per target, not new logic.

See [DESIGN.md](DESIGN.md) for the architecture and the backend seam,
[MOBILE.md](MOBILE.md) for the iPhone/iPad data path, [PROTOCOL.md](PROTOCOL.md) for
the per-verb model mapping, and
[decisions/fixed-native-ui-matrix.md](decisions/fixed-native-ui-matrix.md) for the
fixed framework matrix.

## 1. Targets and shells

The framework matrix is fixed and every shell is native:

| Platform / idiom | SwiftUI shell | Imperative/native shell | Backend |
|---|---|---|---|
| macOS | `ShellMacSwiftUI` | `ShellMacAppKit` | `Backend.LocalSubprocess` over local `cupertino serve` |
| iPhone | `ShelliPhoneSwiftUI` | `ShelliPhoneUIKit` | `Backend.LocalEmbedded` over local databases |
| iPad | `ShelliPadSwiftUI` | `ShelliPadUIKit` | `Backend.LocalEmbedded` over local databases |
| Linux | n/a | `ShellLinuxQt` | `Backend.LocalEmbedded` over local databases |
| Windows | n/a | `ShellWindowsQt` | `Backend.LocalEmbedded` over local databases |

The current code still has legacy package/app names (`ShellSwiftUI`, `ShellUIKit`,
`ShellAppKit`, `CupertinoMobileSwiftUI`, `CupertinoMobileUIKit`) and adaptive mobile
targets. The design target is split per idiom as shown above. iPhone and iPad are
different native presentations, not one hidden size-class-adaptive shell.

No shortcut counts as implementing a target: no SwiftUI hosted inside UIKit/AppKit, no
UIKit/AppKit wrapped to satisfy SwiftUI, no Qt replacement with a web UI or remote UI.
Each shell binds the identical `Feature.*` view models and owns only presentation.

## 2. Backends and their latency profiles (the thing the UI must absorb)

The same screens run over different backends with very different timing. The UI is
designed around the slowest one and degrades gracefully on the faster ones.

| Backend | Used by | Connect cost | Per-call cost | Failure modes |
|---|---|---|---|---|
| `Backend.LocalSubprocess` (MCP over `cupertino serve`) | macOS | **High**: spawns a subprocess, performs the MCP `initialize` + `notifications/initialized` handshake. Seconds on a cold start. | **Variable**: stdio round-trip plus a server-side FTS query. Tens to hundreds of ms, occasionally more for large results. | subprocess fails to launch, handshake hang, decode error, server crash, timeout. |
| `Backend.LocalEmbedded` + `MockReader` | iPhone/iPad today | None (in-memory JSON). | Effectively zero. | none in practice (a decode failure yields an empty corpus). |
| `Backend.LocalEmbedded` + `CupertinoDataEngine` | iPhone/iPad/Linux/Windows planned | Low: open local read-only SQLite databases and assert their versions. | Low: single-digit to tens of ms; first query and very large result sets cost more. | corpus file missing, unreadable, stale, or download/cache failure. |

**Design rule:** treat every backend call as asynchronous and cancellable, show progress
the moment a call is in flight, never block the whole window on one column's load, and
always offer a path out of a failure. A screen that looks correct only against the
instant mock is not done; it must look correct against the MCP runtime too.

## 3. Layout per platform and device

All shells are a sidebar-led split: **frameworks** in the sidebar, the **selected
framework's document** in the detail. (Search, samples, and code intelligence are
section 6.)

### 3.1 Mac (macOS)
- Three-region window built on `NSSplitViewController` (AppKit) and a balanced
  `NavigationSplitView` (SwiftUI): sidebar plus detail today, with room for a middle
  document-list column when search/samples land.
- Unified toolbar with a single leading sidebar toggle pinned to the title area
  (`NSToolbarItem.isNavigational`), so it does not slide away when the sidebar collapses.
- The window opens with the sidebar visible; minimum thicknesses keep every region
  usable; the detail takes the slack on resize.
- Sidebar and detail are always visible together; the user collapses the sidebar by
  choice, not because a layout forced it.

### 3.2 iPad (regular width)
- SwiftUI: `NavigationSplitView` with `columnVisibility = .all` and
  `.navigationSplitViewStyle(.balanced)`, so the list and detail are visible together in
  both orientations rather than the detail-prominent default that hides the sidebar.
- UIKit: `UISplitViewController(style: .doubleColumn)` with `preferredDisplayMode =
  .oneBesideSecondary` and `preferredSplitBehavior = .tile`.
- Narrow multitasking (Slide Over, a thin Split View, Stage Manager at small sizes) is a
  compact environment; it collapses to the iPhone presentation below, then restores.

### 3.3 iPhone (compact width)
- One pane at a time in a navigation stack: the framework list is the root; selecting a
  framework pushes the document. This is the platform idiom (per the HIG, a split view
  belongs in a regular, not compact, environment).
- SwiftUI collapses the `NavigationSplitView` automatically; UIKit pins the collapse to
  the primary column and pushes the detail with `show(.secondary)`.
- Selection deselects on return (push navigation), unlike the persistent highlight used
  in the regular-width split.

### 3.4 iPhone Plus / Pro Max, landscape
- These devices are **regular width in landscape**, so the same two-column split as iPad
  applies and the list and detail show together. In portrait they are compact and behave
  like 3.3. Standard iPhones have no regular-width state and are always single-pane.

## 4. State surfaces (every screen, every framework)

Each data region renders one of four states from its view model. The surface differs per
UI framework; the states do not.

| State | SwiftUI | AppKit | UIKit | Qt |
|---|---|---|---|---|
| Loading | `ProgressView` | `NSProgressIndicator` (spinning) | `UIActivityIndicatorView` | `QProgressBar` or busy indicator |
| Loaded | content | content | content | content |
| Empty | `ContentUnavailableView` | centered symbol + label | centered symbol + label | empty-state widget |
| Error | `ContentUnavailableView` + Retry | label + Retry button | label + Retry button | error widget + Retry action |

The view models already model this with a single `state` / `documentState` enum so the
invalid combinations (loading and failed at once) are unrepresentable.

## 4.1 Main-thread binding

Every concrete shell updates UI objects on its UI thread. SwiftUI makes this feel less
manual through `@MainActor` views and Observation, but the shared view models remain
main-actor-facing so UIKit, AppKit, and Qt cannot receive accidental background-thread
updates. UIKit and AppKit controllers render from the main actor. Qt widgets, models,
and signal handlers render on the Qt GUI thread; embedded-engine callbacks marshal back
before touching `QObject`, `QAbstractItemModel`, or widgets.

## 5. Loading and delay design (the cupertino-runtime targets)

This section is the reason the document exists. On the MCP-backed macOS target, latency
is real and variable; the UI must stay responsive and honest.

### 5.1 Connect / first paint
- macOS: the first `connect()` spawns `cupertino serve` and performs the handshake. The
  sidebar shows a **connecting** state (spinner plus "Starting cupertino...") rather than
  an empty list, until `listFrameworks()` returns. The window chrome (toolbar, empty
  detail) paints immediately so the app never looks frozen.
- Embedded targets: the current iPhone/iPad mock is instant, so the connecting state
  flashes by or is skipped. The state is kept in the view model because the real SQLite
  engine reintroduces an open/download/cache cost, and Qt desktop targets need the same
  honest startup surface.

### 5.2 Per-selection load
- Selecting a framework starts an async document load; the detail shows a spinner while
  it runs. The sidebar stays interactive: the user can pick a different framework
  immediately.
- The load is **cancellable**. Selecting framework B cancels the in-flight load for A
  (the view model cancels the prior task and ignores a cancelled result), so a slow MCP
  read never lands stale content in the detail. This is correctness on MCP and harmless
  on the mock.

### 5.3 Search
- The search field debounces input (about 250 ms) before issuing a query, so typing does
  not flood the MCP server with superseded requests.
- Each keystroke-driven query supersedes the previous one; the in-flight query is
  cancelled. Results render incrementally where the backend supports it; otherwise a
  single spinner sits in the results column.
- An empty query shows recent or suggested content, not a spinner.

### 5.4 Timeouts, retries, and honesty
- MCP calls carry a soft budget. Past a few seconds with no result, the loading surface
  gains a "still working" note rather than implying a hang.
- Any failure (subprocess launch, handshake, decode, timeout, server crash) surfaces as
  the error state with a Retry that re-runs only the failed call. A successful connect is
  not torn down by a later failed call, so Retry does not respawn the subprocess.
- The mobile mock does not fail in practice; the embedded engine surfaces missing,
  stale, unreadable, or not-yet-downloaded corpus errors through the same path.

### 5.5 What not to do
- Do not block the whole window or the sidebar on one detail load.
- Do not show a blank pane during a load; show the loading surface.
- Do not leave a spinner with no escape; every long operation can fail into Retry.
- Do not tune the UI to the instant mock; verify the loading and error states against the
  MCP runtime and against a cold embedded SQLite open/download path.

## 6. Feature screens

| Feature | Status | Screen | Latency notes |
|---|---|---|---|
| Framework browser | shipped | sidebar list of frameworks with document counts | one `listFrameworks()` at connect; the costly step on macOS is the connect itself (5.1). |
| Document reader | shipped | detail renders the selected framework's document markdown | one `searchDocs` (scoped to the framework) then one `readDocument`; per-selection spinner and cancellation (5.2). |
| Search | shipped | search field plus framework-grouped Docs results (Everything scope source-bucketed) feeding the reader; Docs scope (per-source, with framework and platform-minimum filters) and unified Everything scope (docs, samples, packages bucketed) | debounced, cancellable, superseding queries (5.3). |
| Samples browser | planned | sample-project list plus a file reader | adopts `CupertinoDataKit.Sample.Index.Reader`; list and per-file reads each get a loading surface. |
| Code intelligence | planned | symbol / conformance / inheritance results | adopts `Search.SymbolReading`; potentially large result sets, so paginate or cap and say so. |

Planned features adopt the matching CupertinoDataKit slice at the backend seam and reuse
the four state surfaces in section 4; none of them change the latency rules in section 5.

## 7. Markdown rendering

Documents are rendered from markdown. Today the detail renders inline styling with
preserved whitespace (headings and fenced code remain literal), which is adequate for the
captured abstracts. A full block renderer (headings, lists, code blocks, links into other
documents) is a later milestone and is a presentation change only; it does not touch the
backend seam or the state model.

## 8. Verification

UI behaviour is verified the way the runtime exercises it:
- The framework-to-document flow has an XCUITest that drives a real tap on a compact
  iPhone and waits for the asynchronously loaded document, because that path
  (`UISplitViewController` collapse plus `show(.secondary)`) cannot be reached by a unit
  test.
- Layout per device and orientation is checked on simulators (iPhone, iPhone Max
  landscape, iPad, iPad portrait) before a UI change is called done.
- The loading, empty, and error surfaces are exercised against the MCP runtime on macOS,
  not only against the instant mobile mock.
