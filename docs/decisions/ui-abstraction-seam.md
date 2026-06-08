# Decision: where the UI abstraction seam sits across SwiftUI, UIKit, AppKit, and Qt

**Status:** Accepted (records existing practice and its research grounding).
**Date:** 2026-06-08. Revised the same day with primary-source citations and a code
audit (see "Code audit" below).
**Anchors:** [DESIGN.md §4 "UI layer (eight parallel, fully native variants)"](../DESIGN.md)
and its "Building the variants in parallel is a seam-discovery method" subsection;
[UI-DESIGN.md §1 "Targets and shells"](../UI-DESIGN.md);
[fixed-native-ui-matrix.md](fixed-native-ui-matrix.md);
[rules/shared-protocols.md](../rules/shared-protocols.md).

## Context

The repo ships the same app over multiple native UI frameworks (SwiftUI, UIKit,
AppKit, Qt) and idioms (Mac, iPhone, iPad, Linux, Windows). The recurring design question is: at what
layer do the frameworks become "the same thing," and how much of the view should
be shared rather than written once per framework?

A specific, intuitive proposal keeps resurfacing: abstract the view itself so the
shared layer "does not know who implements the search bar or the tree, or on which
device. It only knows there is a rectangle on the screen." Under that proposal there
would be a shared `SearchBar` or `TreeView` that some framework-specific code draws,
and the shared layer would compose abstract widgets without knowing their concrete
type.

This decision records why we do **not** do that, where the seam sits instead, and
the prior research that settles the question, so it does not have to be relitigated
each time the proposal returns.

## Decision

We abstract **task, dialogue, and domain data** up into the shared layer, and we
hand-write the **concrete widgets** natively, once per framework. Concretely:

- The shared, framework-agnostic seam is `PresentationBridge`, the `@Observable`
  feature view models (`Feature.*.ViewModel`), and the value types in `AppModels`.
  These hold all state and behavior and reference no control type. `Feature.Search.ViewModel` exposes
  `text`, `scope`, `sources`, `run()`, `toggle(_:)`; it does not know a search bar
  exists.
- Data that is genuinely modality-neutral is shared as **data**, not as an abstract
  widget. `Presentation.SearchResultNode` (`{ id, title, subtitle?, children }`) is
  a domain tree, not a tree-view control; `MarkdownRendering` emits a themed
  `AttributedString`, not a document-view control.
- Each shell owns its own native widget and binds it to that contract. The search
  field is `NSSearchField` / `UISearchController` / `.searchable` / a Qt search
  widget in the concrete frameworks; the tree is `NSOutlineView` / a UIKit outline
  list / `OutlineGroup` / `QAbstractItemModel` plus Qt views. None of these is named
  or described by the shared layer.

We do **not** introduce a shared abstract-widget layer (no shared `SearchBar`, no
"virtual toolkit" of logical controls reified per framework). Writing each view once
per native shell is accepted as the price of keeping every shell fully idiomatic.
The fixed showcase matrix also forbids hosting shortcuts: no SwiftUI hosted inside
UIKit/AppKit, no UIKit/AppKit wrapped to satisfy SwiftUI, and no non-Qt Linux/Windows UI.

## Research grounding

The "rectangle on the screen" proposal is not new; it is the **Logical Presentation
Component** of the Arch/Slinky model and the **Abstract Interaction Object** of the
CAMELEON Reference Framework. The field studied this exact seam for three decades and
the findings are what make the decision above evidence-based rather than taste.

- **Arch / Slinky (Bass et al., 1992).** Decomposes an interactive system into a
  toolkit-independent **Logical Presentation Component** ("logical presentation
  objects provided by a virtual toolkit") and a toolkit-dependent **Interaction
  Toolkit Component** ("physical interaction objects, widgets and interactors"). The
  "slinky" metaphor is that the seam between them slides: you can push weight toward
  the abstract side or the native side. The "abstract to a rectangle" proposal is
  simply pushing the slinky all the way to the logical side.
- **CAMELEON (Calvary, Coutaz, Vanderdonckt et al., D1.1 report, 2002).** Four levels:
  Tasks and Concepts to **Abstract UI** (Abstract Interaction Objects, platform-
  independent) to **Concrete UI** (Concrete Interaction Objects, real widgets) to
  **Final UI** (running code). The primary report defines the moving parts precisely:
  - **Context of use** is the triple *(user, platform, environment)*, and the report
    states it "is a synonym for target." So "on which device" is the platform axis of
    context of use, and "we do not know who draws the search bar" is the AUI level.
  - Two different generation moves: **reification** is vertical (abstract description
    to concrete code); **translation** is horizontal, "transformations applied to
    descriptions while preserving their level of abstraction." Mapped here: we *reify*
    by hand at the final step (an AUI data object becomes a native row) and *translate*
    the same view model across the three shells. The two moves have different costs:
    translation across shells is cheap and safe; reification to a concrete widget is
    the step the literature found must not be automated.
  - **Plasticity** (Thevenin 1999, quoted in D1.1) is "the capacity of an interactive
    system to withstand variations of contexts of use while preserving usability." It
    is the precise name for what the repo wants across Mac, iPhone, and iPad.
  - The report flags as a *limiting implicit assumption* that windowing systems "model
    windows as rectangular drawables." The "rectangle on the screen" is named in the
    source as the constraint to design around, not the abstraction to aim for.
- **Presentation Model / MVVM (Fowler 2004; Microsoft/WPF 2005), descended from MVC
  (Reenskaug, Xerox PARC 1979) and PAC (Coutaz 1987).** Fowler's Presentation Model
  is "a fully self-contained class that represents all the data and behavior of the
  UI window, but without any of the controls used to render it," a "platform-
  independent abstraction of a View." That is exactly `Feature.*.ViewModel`. The repo
  already sits on this well-studied rung.
- **The load-bearing finding: full reification was tried and measured to fail.** The
  model-based UI community spent decades generating the concrete UI from the abstract
  model (UIML, UsiXML, MARIA, TERESA, SUPPLE). Peer-reviewed retrospectives report
  that automatically generated interfaces "were not of very good quality, and it was
  not feasible to produce good quality interfaces for even moderately complex
  applications from just data and task models," citing lowest-common-denominator
  widgets, lack of design control, and a ceiling too low to express good native UI
  (Myers et al.; SoSyM 2018 evaluation).
- **The maximal version has a documented industrial outcome.** Pushing the slinky all
  the way to the top, one abstract widget API mapped onto native peers per platform,
  has been tried at industrial scale. It was so pinned to the lowest common denominator
  that it was abandoned in favor of a toolkit that stopped using native peers and drew
  everything itself. The abstract-widget layer did not survive contact with real native
  UIs; the slinky-at-the-top is the documented failure mode.

The mature, evidence-based position the field converged on: abstract the task, the
dialogue, and the domain data (high value, low risk) and stop the reification before
the concrete widget, doing that last mile by hand per toolkit. That is the decision
above.

## How it maps to this codebase

| Arch component | CAMELEON level | cupertino-desktop |
|---|---|---|
| Functional Core | Domain | `AppModels` + the `cupertino` server |
| Functional Core Adapter | (adapter) | `Backend.Documentation` protocol + its adapters |
| Dialogue Component (toolkit-independent) | Abstract UI | `Feature.*.ViewModel` (`run`, `toggle`, `select`) |
| Logical Presentation (as data, not widgets) | Abstract UI | `PresentationBridge` (`Presentation.SearchResultNode`, `Presentation.LoadState`), `Model.DocHit`, the `MarkdownRendering` `AttributedString` |
| Interaction Toolkit Component | Concrete / Final UI | `ShellMacSwiftUI`, `ShellMacAppKit`, `ShelliPhoneSwiftUI`, `ShelliPhoneUIKit`, `ShelliPadSwiftUI`, `ShelliPadUIKit`, `ShellLinuxQt`, `ShellWindowsQt` native views |

## Code audit (2026-06-08)

The patterns above were checked against the actual sources, not assumed:

- **Seam is data, reified by hand: confirmed.** `Feature.FrameworkBrowser.ViewModel`
  exposes `LoadState`/`DocumentState` enums and `frameworks: [Model.Framework]`;
  `UI.RootModel` holds only `selectedFrameworkID: String?`. No control type appears.
  Each shell reifies natively: SwiftUI `List(...)`, AppKit `NSTableView` (`.sourceList`),
  UIKit `UITableView`.
- **Presentation Model vs Passive View asymmetry: confirmed in code.** SwiftUI binds
  `@Bindable` (`ShellSwiftUI/UI.RootView.swift`, `UI.SearchView.swift`): automatic
  Observation sync. AppKit and UIKit both run `withObservationTracking { _ = state }
  onChange: { render(); trackState() }` (`UI.FrameworkSidebarViewController.swift` in
  each shell): a hand-driven `render()` plus re-arm. `UI.RootModel`'s own comment
  states it: "SwiftUI via `@Bindable`, AppKit via `withObservationTracking`." This is
  the Fowler synchronization tradeoff instantiated: the SwiftUI shell pays no manual
  sync, the AppKit/UIKit shells are deliberately the dumbest possible view. The
  asymmetry in shell thickness is the pattern working, not a defect to normalize.
- **`SearchResultNode` is load-bearing for Docs-scope search (#51).** `Presentation.SearchResultNode` is a
  recursive `Hashable, Identifiable` tree; `Presentation.SearchResultTree.make(docs:)` groups one level (framework to
  hits) and all three search shells reify `docsTree` natively. The framework browser tree
  (#49/#50) is still unwired, so the "grow the Logical Presentation as data" consequence
  below remains latent for browse.
- **Color/typography is already shared as data; no token decision is warranted.**
  `MarkdownRendering/Markdown.Theme` is a token-like table (semantic roles, an
  11-entry syntax-role color map, fonts derived from one `basePointSize`, platform
  bridged across `UIColor`/`NSColor` and `UIFont`/`NSFont`). Chrome uses Apple system
  semantic colors directly (`.label`, `.secondaryLabel`, `.systemBackground`), which
  adapt to light/dark per `rules/colors.md`. The only token-shaped gap left is a
  shared type scale for chrome, which is the existing #35 Dynamic Type item, not a new
  concern. A separate design-tokens decision was considered and dropped as unjustified.
- **Diffable snapshots are a future improvement, not current state.** No shell uses
  `NSDiffableDataSource`; AppKit/UIKit flatten into a hand-built `Row` snapshot and
  reload. `ResultNode`'s `Hashable` identity makes it snapshot-ready when #49/#50/#51
  build the outline.

## Consequences

- Each view is written once per native shell. This is slower than sharing a widget
  layer, and it is the accepted cost of a high ceiling: 30 years of model-based UI
  evaluation says you cannot get good native UI from generation.
- The shared **Logical Presentation may grow, but only as data.** Adding more
  AIO-shaped node models (the framework tree in #50, inheritance graphs, formatted
  read-only content) is encouraged, because data-shaped abstract objects reify
  cleanly across toolkits, the same reason `ResultNode` and the markdown
  `AttributedString` already work.
- The shared layer must **not** grow an abstract *widget* layer. A proposed shared
  `SearchBar`/`TreeView` control, or any "virtual toolkit" of logical widgets reified
  per framework, is rejected by this decision: it reproduces the abstract-widget
  failure mode documented above, not eight good native experiences. The guard from `shared-protocols.md` still applies: a seam that
  fits one framework but forces another into an unnatural shape belongs in the shells.

## When to revisit

Revisit if a future requirement makes a large UI surface genuinely modality-neutral
and read-only (where reification is known to work), or if we ever accept a single
self-rendered UI that consciously gives up native fidelity. Neither is true today;
native fidelity is the product's thesis.

## References

- A Unifying Reference Framework for Multi-Target User Interfaces (CAMELEON),
  Calvary, Coutaz, Thevenin, Limbourg, Bouillon, Vanderdonckt, 2003:
  <https://www.researchgate.net/publication/222218921_A_Unifying_Reference_Framework_for_Multi-Target_User_Interfaces>
- CAMELEON D1.1 reference-framework report (primary, read directly for the
  reification/translation, context-of-use, and plasticity definitions):
  <http://giove.isti.cnr.it/projects/cameleon/pdf/CAMELEON%20D1.1RefFramework.pdf>
- Coutaz, Software Architecture Modeling for User Interfaces (Arch/Slinky, Seeheim,
  PAC): <http://iihm.imag.fr/publs/2001/Encyclop01.chap.coutaz.doc>
- W3C, Introduction to Model-Based User Interfaces: <https://www.w3.org/TR/mbui-intro/>;
  Abstract UI Models: <https://www.w3.org/TR/abstract-ui/>
- Furnas, Generalized Fisheye Views, CHI '86 (primary, read directly for the
  Degree-of-Interest formula): <https://dl.acm.org/doi/10.1145/22627.22342>
- Fowler, Passive View: <https://martinfowler.com/eaaDev/PassiveScreen.html>;
  Humble Object: <https://martinfowler.com/bliki/HumbleObject.html>
- Myers, Hudson, Pausch, Past, Present and Future of User Interface Software Tools,
  ACM TOCHI 2000: <https://dl.acm.org/doi/pdf/10.1145/344949.344959>
- Past, Present and Future of Model-Based User Interface Development:
  <https://www.researchgate.net/publication/220584891_Past_Present_and_Future_of_Model-Based_User_Interface_Development>
- Evaluating user interface generation approaches: model-based versus model-driven
  development, SoSyM 2018: <https://link.springer.com/article/10.1007/s10270-018-0698-x>
- Fowler, Presentation Model: <https://martinfowler.com/eaaDev/PresentationModel.html>;
  GUI Architectures: <https://martinfowler.com/eaaDev/uiArchs.html>
- Akiki, Bandara, Yu, Adaptive Model-Driven User Interface Development Systems, ACM
  Computing Surveys 2014: <https://oro.open.ac.uk/39809/1/Akiki_Bandara_Yu_ACMCSUR2014.pdf>
