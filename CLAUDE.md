# CLAUDE.md

Guidance for Claude Code (and other coding agents) working in this repository.

## Project

Cupertino Desktop is a native UI showcase for browsing Apple developer documentation,
Swift Evolution, and sample code offline across macOS, iPhone, iPad, Linux, and
Windows. macOS is a thin GUI client over the
[`cupertino`](https://github.com/mihaelamj/cupertino) MCP server: it spawns
`cupertino serve` as a subprocess and talks to it over stdio via the `MCPClient`
library. iPhone, iPad, Linux, and Windows use a local embedded read engine over
downloaded or bundled databases. It does **not** reimplement search, indexing,
crawling, or storage; Cupertino-owned engine code owns all of that.

The repo ships a fixed native framework matrix: macOS SwiftUI/AppKit, iPhone
SwiftUI/UIKit, iPad SwiftUI/UIKit, Linux Qt, and Windows Qt. These are showcase
variants, not options to collapse into one winner. No variant may be satisfied by
hosting one framework inside another. Types are namespaced under short per-module
semantic anchors (`Model`, `Backend`, `Feature`, `UI`, `Markdown`); there is no
project-name root prefix, the Swift module already namespaces each target.
Architecture: [docs/DESIGN.md](docs/DESIGN.md) and
[docs/decisions/fixed-native-ui-matrix.md](docs/decisions/fixed-native-ui-matrix.md).

Target platforms: macOS 15+, iOS 17+, Linux/Windows Qt, Swift 6.2+, Xcode 16+.

## Rule loading (do this first)

At session start, read [docs/rules/README.md](docs/rules/README.md) and the rules
it marks as always relevant. Confirm by replying with the token `rules-loaded` and
naming the rule files that apply to the current task. If you cannot name them, you
have not loaded them.

## Read first

- [AGENTS.md](AGENTS.md) - the agent guide: language policy, workflow, commands.
- [docs/DESIGN.md](docs/DESIGN.md) - the architecture: backend seam, package layout,
  fixed native UI matrix, milestones.
- [docs/rules/](docs/rules/) - the coding conventions. Start at
  [docs/rules/README.md](docs/rules/README.md).
- [CONTRIBUTING.md](CONTRIBUTING.md) - contributor workflow.

## Non-negotiables

- **Swift for shared Apple/core code; Qt for Linux/Windows UI.** Documentation content
  arrives from the server or embedded engine as markdown/text and is rendered natively.
  No JavaScript, no web build step.
- **Clarify before coding.** Do not assume requirements. Surface options when a
  real trade-off exists. Do not pre-abstract; add abstraction only at the second
  real consumer.
- **Inject dependencies through `init`** (or Point-Free `@Dependency`). No
  singletons. No force-unwrapping in shipping code. The backend is reached only
  through the `DocumentationBackend` protocol seam; `MCP.Client` stays out of the UI.
- **Namespace every public type** under an `enum`/`struct` that mirrors its
  folder; one non-private type per file; file named for the qualified type.
- **Fixed native UI matrix.** macOS uses SwiftUI and AppKit, iPhone uses SwiftUI and
  UIKit, iPad uses SwiftUI and UIKit, and Linux/Windows use Qt. Each shell is native;
  no SwiftUI/AppKit/UIKit hosting shortcut counts. MCP subprocess is macOS-only.
- **Verify before claiming done.** Run `swift build` and `swift test`; cite the
  output. Never say "should pass".
- **No AI attribution, no em dashes** in any committed text (commits, comments,
  docs, PRs). Enable the hooks: `git config core.hooksPath .githooks`.

## Architecture in one breath

ExtremePackaging monorepo: `Main.xcworkspace` at root, one `Package.swift` under
`Packages/`, app targets under `Apps/`. Layers run one direction only:
**Foundation -> Infrastructure -> Features -> UI -> Apps**. Backend adapters are the
only modules that touch Cupertino-specific implementation; everything above them sees
the `Backend.Documentation` protocol. See [docs/DESIGN.md](docs/DESIGN.md).

## Commands

```sh
swift build                 # build all packages
swift test                  # run package tests
open Main.xcworkspace       # then run an app target in Xcode
```

The `Packages/Package.swift` and app targets are not committed yet; these are the
intended commands once the skeleton (milestone M0) lands. See
[CONTRIBUTING.md](CONTRIBUTING.md).
