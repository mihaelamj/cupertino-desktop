# CLAUDE.md

Guidance for Claude Code (and other coding agents) working in this repository.

## Project

Cupertino Desktop is a **native macOS app for browsing Apple developer documentation,
Swift Evolution, and sample code offline**. It is a thin GUI client over the
[`cupertino`](https://github.com/mihaelamj/cupertino) MCP server: it spawns
`cupertino serve` as a subprocess and talks to it over stdio via the `MCPClient`
library. It does **not** reimplement search, indexing, crawling, or storage; the
server owns all of that.

The repo ships **two app targets in parallel, SwiftUI and AppKit**, over one shared
backend, so the two UI approaches can be compared before a final framework choice.
A native iOS variant over the same backend is a possible future concern. The
namespace root is `CupertinoDesktop`. Architecture: [docs/DESIGN.md](docs/DESIGN.md).

Target platform: macOS 15+, Swift 6.2+, Xcode 16+.

## Rule loading (do this first)

At session start, read [docs/rules/README.md](docs/rules/README.md) and the rules
it marks as always relevant. Confirm by replying with the token `rules-loaded` and
naming the rule files that apply to the current task. If you cannot name them, you
have not loaded them.

## Read first

- [AGENTS.md](AGENTS.md) - the agent guide: language policy, workflow, commands.
- [docs/DESIGN.md](docs/DESIGN.md) - the architecture: backend seam, package layout,
  the two app targets, milestones.
- [docs/rules/](docs/rules/) - the coding conventions. Start at
  [docs/rules/README.md](docs/rules/README.md).
- [CONTRIBUTING.md](CONTRIBUTING.md) - contributor workflow.

## Non-negotiables

- **Swift only.** Documentation content arrives from the server as markdown/text and
  is rendered natively (AttributedString / WebKit). No JavaScript, no web build step.
- **Clarify before coding.** Do not assume requirements. Surface options when a
  real trade-off exists. Do not pre-abstract; add abstraction only at the second
  real consumer.
- **Inject dependencies through `init`** (or Point-Free `@Dependency`). No
  singletons. No force-unwrapping in shipping code. The backend is reached only
  through the `DocumentationBackend` protocol seam; `MCP.Client` stays out of the UI.
- **Namespace every public type** under an `enum`/`struct` that mirrors its
  folder; one non-private type per file; file named for the qualified type.
- **Apple-only, two UI frameworks.** This is a macOS app (iOS later), not a Linux
  product. Where SwiftUI and AppKit diverge, share logic in the Features layer and
  keep each framework's view code thin over the same `@Observable` view model.
  Spawning the `cupertino serve` subprocess is expected and allowed.
- **Verify before claiming done.** Run `swift build` and `swift test`; cite the
  output. Never say "should pass".
- **No AI attribution, no em dashes** in any committed text (commits, comments,
  docs, PRs). Enable the hooks: `git config core.hooksPath .githooks`.

## Architecture in one breath

ExtremePackaging monorepo: `Main.xcworkspace` at root, one `Package.swift` under
`Packages/`, app targets under `Apps/`. Layers run one direction only:
**Foundation → Infrastructure → Features → Apps**. `MCPBackend` (Infrastructure) is
the only module that imports the `cupertino` package; everything above it sees the
`DocumentationBackend` protocol. See [docs/DESIGN.md](docs/DESIGN.md).

## Commands

```sh
swift build                 # build all packages
swift test                  # run package tests
open Main.xcworkspace       # then run an app target (SwiftUI or AppKit) in Xcode
```

The `Packages/Package.swift` and app targets are not committed yet; these are the
intended commands once the skeleton (milestone M0) lands. See
[CONTRIBUTING.md](CONTRIBUTING.md).
