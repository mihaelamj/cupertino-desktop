# Decision: fixed native UI matrix and framework bridge

**Status:** Accepted.
**Date:** 2026-06-08.
**Supersedes:** Any earlier wording that treats the UI frameworks as optional,
compares them toward a final single choice, excludes Linux/Windows Qt UI, or allows
a remote backend.
**Anchors:** [DESIGN.md](../DESIGN.md), [UI-DESIGN.md](../UI-DESIGN.md),
[ui-abstraction-seam.md](ui-abstraction-seam.md),
[rules/cross-platform.md](../rules/cross-platform.md).

## Context

The UI framework matrix is fixed and is part of the product thesis. Cupertino
Desktop is a native UI showcase over one shared documentation corpus and one shared
presentation core:

| Platform / idiom | Native UI frameworks |
|---|---|
| macOS | SwiftUI and AppKit |
| iPhone | SwiftUI and UIKit |
| iPad | SwiftUI and UIKit |
| Linux | Qt |
| Windows | Qt |

No framework in that table is a placeholder or a candidate to replace another. The
matrix will not be collapsed into one "winner" and will not be satisfied by hosting
one framework inside another.

The backend matrix is also fixed:

- macOS is the only platform that talks to Cupertino through MCP, by spawning the
  local `cupertino serve` process.
- iPhone, iPad, Linux, and Windows do not use MCP and do not use a remote service.
  They run a local embedded read engine over an installed Cupertino catalog that only
  Cupertino-owned code opens.
- The embedded read path is Cupertino code refactored into app-embeddable packages.
  It is not a second search implementation in this repo.

## Decision

The shared layer is a presentation-model bridge, not an abstract widget toolkit.
Shared code owns domain values, presentation state, commands, stable identifiers, and
feature intents. In code, that boundary is the `PresentationBridge` package plus the
feature view models above it. Each concrete UI framework owns its widgets, navigation
containers, lifecycles, delegates, bindings, and rendering.

There are eight native shells:

| Shell | UI framework | Native root | Backend family |
|---|---|---|---|
| `ShellMacSwiftUI` | SwiftUI | `App` / `Scene` / `View` | local MCP subprocess |
| `ShellMacAppKit` | AppKit | `NSApplication` / `NSViewController` | local MCP subprocess |
| `ShelliPhoneSwiftUI` | SwiftUI | `App` / `Scene` / `View` | local embedded engine |
| `ShelliPhoneUIKit` | UIKit | `UIApplicationDelegate` / `UIViewController` | local embedded engine |
| `ShelliPadSwiftUI` | SwiftUI | `App` / `Scene` / `View` | local embedded engine |
| `ShelliPadUIKit` | UIKit | `UIApplicationDelegate` / `UIViewController` | local embedded engine |
| `ShellLinuxQt` | Qt | `QApplication` / `QMainWindow` | local embedded engine |
| `ShellWindowsQt` | Qt | `QApplication` / `QMainWindow` | local embedded engine |

No shortcut counts as implementing a shell:

- No `UIHostingController` to satisfy a UIKit shell.
- No `NSHostingController` to satisfy an AppKit shell.
- No `UIViewRepresentable` or `NSViewRepresentable` to satisfy a SwiftUI shell.
- No AppKit view wrapped inside SwiftUI to avoid writing the SwiftUI surface.
- No SwiftUI view hosted inside AppKit/UIKit to avoid writing native controllers.
- No web view, remote UI, or alternate Linux/Windows toolkit in place of Qt.

Small OS integration wrappers are allowed only when the framework itself has no API for
the platform service and the wrapper is not the feature UI. The primary feature
surface must be native to its shell.

## Main-thread rule

All concrete UI work happens on the UI thread:

- SwiftUI views are `@MainActor` by Apple documentation in the local Cupertino corpus,
  and SwiftUI hides much of the update scheduling behind its state system. The shell
  still treats presentation state as main-actor-facing.
- UIKit and AppKit controllers update retained objects on the main actor.
- Qt widgets, models, and signal handlers run on the Qt GUI thread. Any embedded
  engine callback that completes off the GUI thread must marshal back before touching
  `QObject`, `QAbstractItemModel`, or widgets on Linux or Windows.

The shared feature view models are `@MainActor`. Backend calls may perform work off the
main actor, but their results are applied through main-actor feature methods. This is
not a SwiftUI-only concern; it is required so the UIKit, AppKit, and Qt shells cannot
receive accidental background-thread UI updates.

## Per-framework obligations

### macOS SwiftUI

Use SwiftUI's value tree and Observation binding as the native surface:
`NavigationSplitView`, `List`, `.searchable`, `ToolbarContent`, `Commands`, and native
SwiftUI state bindings. It may call the same feature intents as every other shell, but
it does not borrow AppKit controllers to render feature screens.

### macOS AppKit

Use retained AppKit objects: `NSWindow`, `NSViewController`, `NSSplitViewController`,
`NSToolbar`, `NSTableView` / `NSOutlineView`, `NSSearchField`, delegates, data sources,
and the responder chain where appropriate. It observes shared view models and renders
imperatively. It does not host SwiftUI views to satisfy the AppKit variant.

### iPhone SwiftUI

Use SwiftUI for a compact, stack-led iPhone experience. Navigation is single-pane by
default, with push-style detail flow and native SwiftUI search and toolbar surfaces.
It is not the iPad SwiftUI shell with size-class switches hidden inside it.

### iPhone UIKit

Use UIKit controllers and views: `UINavigationController`, `UIViewController`,
`UITableView` / `UICollectionView`, `UISearchController`, diffable snapshots where
useful, and target/action or delegate flows. It does not host SwiftUI views.

### iPad SwiftUI

Use SwiftUI's regular-width multi-column idiom directly, especially
`NavigationSplitView`, column visibility, and native toolbar/search placement. It is a
separate iPad shell, not the iPhone SwiftUI shell made adaptive.

### iPad UIKit

Use UIKit's regular-width controller model, especially `UISplitViewController`, sidebars,
collection-view lists or outlines, and UIKit toolbar/search placement. It is a separate
iPad shell, not the iPhone UIKit shell made adaptive.

### Linux Qt

Use Qt as the Linux UI framework: `QApplication`, `QMainWindow`, `QAbstractItemModel`,
proxy models, delegates, actions, menus/toolbars, and signals/slots. The Qt shell must
not use SwiftUI, UIKit, AppKit, a web frontend, or a remote Cupertino service. Its
adapter boundary is a language/runtime adapter to the shared presentation and embedded
engine, not a replacement UI toolkit.

### Windows Qt

Use the same Qt architectural family on Windows: `QApplication`, `QMainWindow`,
`QAbstractItemModel`, proxy models, delegates, actions, menus/toolbars, and
signals/slots. Windows gets a native Qt app target over the local embedded engine, not
a remote service and not a web frontend.

## GoF mapping

The pattern names are used narrowly:

- **Bridge:** the long-lived separation between shared presentation models and eight
  concrete UI implementations. `PresentationBridge` is the bridge-side package for
  reusable state and logical trees. Both sides vary independently.
- **Adapter:** backend adapters (`LocalSubprocess`, `LocalEmbedded`) and the Qt
  language/runtime binding. Adapters translate; they do not add product policy.
- **Abstract Factory:** app composition roots create matching families: backend,
  root model, platform services, and one shell for the target.
- **Strategy:** platform policies such as debounce, cache opening, platform filters,
  and navigation policy. Cross-target strategies are named protocols, not closure bags.
- **Composite:** document trees, result trees, framework hierarchies, and navigation
  models are shared as data with stable IDs.
- **Observer:** each UI framework uses its native observation mechanism to reflect
  shared state.
- **Mediator:** feature view models coordinate controls and backend calls per feature.
  There is no global UI mediator.

This follows the local `mihaela-patterns` Bridge/Adapter/Abstract Factory/Strategy
guidance and the `mihaela-agents` GoF + DI rule that cross-target seams use named
protocols and value models.

## Research grounding

The scientific and architectural literature supports the boundary above:

- Parnas' information-hiding criterion says modules should hide likely change
  decisions. Here, concrete widget lifecycles are the likely change, so they stay
  inside the native shells.
- UI architecture research treats toolkit choice as a major structural decision, not
  a superficial rendering detail. SEI's UI architecture design-space report and later
  HCI architecture work both frame UI toolkits and application frameworks as forces
  that shape architecture.
- Presentation Model / MVVM separates view state and behavior from controls. This is
  the shared `Feature.*.ViewModel` layer.
- Model-based UI and abstract-widget systems are useful for reasoning, but generated
  native UI repeatedly hits a quality ceiling. Therefore the final reification into
  concrete widgets is manual per framework.
- Qt's own supported-platforms documentation lists Linux/X11 and Windows as desktop
  platforms, and Qt's model/view documentation is model, view, delegate oriented. The
  Qt desktop shells should map shared result/document trees into Qt models rather than
  try to force a SwiftUI/AppKit/UIKit-style widget abstraction into Qt.

Apple framework facts are verified through the local Cupertino corpus, not web docs.
On 2026-06-08, the Homebrew `cupertino` CLI returned SwiftUI `View` as `@MainActor`,
SwiftUI custom views as a declarative hierarchy, UIKit `UISplitViewController` as a
hierarchical container controller, and AppKit `NSOutlineView` / split-view sample docs
for hierarchical navigation. Use `cupertino search` and `cupertino read` for future
Apple-framework checks.

## References

- Parnas, "On the Criteria To Be Used in Decomposing Systems into Modules":
  <https://sunnyday.mit.edu/16.355/parnas-criteria.html>
- Lane, "A Design Space and Design Rules for User Interface Software Architecture":
  <https://www.sei.cmu.edu/library/a-design-space-and-design-rules-for-user-interface-software-architecture/>
- Bass and Kazman, "Software Architectures for Human-Computer Interaction: Analysis
  and Construction":
  <https://www.researchgate.net/publication/2444000_Software_Architectures_for_Human-Computer_Interaction_Analysis_and_Construction>
- Fowler, "Presentation Model":
  <https://martinfowler.com/eaaDev/PresentationModel.html>
- Microsoft, "WPF Apps With The Model-View-ViewModel Design Pattern":
  <https://learn.microsoft.com/en-us/archive/msdn-magazine/2009/february/patterns-wpf-apps-with-the-model-view-viewmodel-design-pattern>
- Qt, "Supported Platforms":
  <https://doc.qt.io/qt-6.10/supported-platforms.html>
- Qt, "Model/View Programming":
  <https://doc.qt.io/qt-6/model-view-programming.html>
