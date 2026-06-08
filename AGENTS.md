# Agent Guide

Guidance for anyone (human or coding agent) writing code in Cupertino Desktop.

## Rule loading (read this first)

At the start of a session, read [docs/rules/README.md](docs/rules/README.md) and
the rules it marks as always relevant. Then confirm you have done so by replying
with the token `rules-loaded`, and name the rule files that apply to the task at
hand. If you cannot name them, you have not loaded the rules. The mechanical gates
(hooks and CI) enforce the checkable rules regardless, but the judgment rules
depend on you having read them.

## What Cupertino Desktop is

A native UI showcase for browsing Apple developer documentation, Swift Evolution,
and sample code offline across macOS, iPhone, iPad, Linux, and Windows. macOS is a thin GUI
client over the [`cupertino`](https://github.com/mihaelamj/cupertino) MCP server:
it spawns `cupertino serve` as a subprocess and calls it over stdio through the
`MCPClient` library. iPhone, iPad, Linux, and Windows use a local embedded read engine over
downloaded or bundled databases. There is no remote backend. Search, indexing, and
storage live in Cupertino-owned engine code, not here.

The repo ships a fixed native framework matrix: macOS SwiftUI/AppKit, iPhone
SwiftUI/UIKit, iPad SwiftUI/UIKit, Linux Qt, and Windows Qt. These are showcase variants, not
options to collapse into one winner. No variant may be satisfied by hosting one
framework inside another. Types are namespaced under short per-module semantic
anchors (`Model`, `Backend`, `Feature`, `UI`, `Markdown`), with no project-name
root prefix. Target: macOS 15+, iOS 17+, Linux/Windows Qt, Swift 6.2+, Xcode 16+. See
[docs/DESIGN.md](docs/DESIGN.md) and
[docs/decisions/fixed-native-ui-matrix.md](docs/decisions/fixed-native-ui-matrix.md).

## Language policy

Swift for shared Apple/core code. Qt is the fixed Linux and Windows UI framework. Documentation
content comes back from the server or embedded engine as markdown/text and is rendered
natively. There is no web output, no client-side scripting, and no JavaScript in build
logic or tooling.

## Rules

Conventions live in [docs/rules/](docs/rules/). Read the surrounding files before
writing code and match what is there.

**Read these for any change to app or backend code:**

- [docs/rules/engineering.md](docs/rules/engineering.md)
- [docs/rules/code-style.md](docs/rules/code-style.md) and
  [docs/rules/namespacing.md](docs/rules/namespacing.md)
- [docs/rules/dependency-injection.md](docs/rules/dependency-injection.md)
- [docs/rules/concurrency.md](docs/rules/concurrency.md)
- [docs/rules/testing.md](docs/rules/testing.md) and
  [docs/rules/verification.md](docs/rules/verification.md)

**Read these for UI work (native framework matrix, no hosting shortcuts):**

- [docs/rules/views.md](docs/rules/views.md) and
  [docs/rules/view-models.md](docs/rules/view-models.md)
- [docs/rules/components.md](docs/rules/components.md),
  [docs/rules/colors.md](docs/rules/colors.md),
  [docs/rules/fonts.md](docs/rules/fonts.md)

**Load the rest on demand**: testing-discipline, documentation, dependency-injection,
systematic-debugging, file-naming, folder-grouping, commits, git-discipline, and the
package set (package-structure, package-architecture, package-import-contract,
shared-protocols, cross-platform) once the `Packages/` workspace lands. The index is
[docs/rules/README.md](docs/rules/README.md).

> Note: `linux-server.md` server rules do not apply to this repo. There are Linux and
> Windows Qt UI targets in the accepted design, but no Linux/Windows server product.
> Cross-platform concerns are the shared core, the local embedded engine, and the native UI matrix.

## Working with the maintainer

How a coding agent works with the maintainer. These govern agent behavior, not
the code.

- Clarify ambiguity before coding. Do not assume requirements.
- When a real trade-off exists, surface two or three options with their
  trade-offs rather than guessing. On obvious blockers (a build break, a bug in
  your own change, a fatal regression) fix without asking. On routine edits with
  no real choice, just do the work.
- A trivial-looking change with non-trivial downstream blast radius (a version
  bump, a public API break, a release artefact, a file-format change) needs the
  maintainer's call on semantics even when the code is one line. The question is
  "1.0.2 to 1.0.3 or to 1.1.0", not "I see three implementations".
- Do not modify an existing screen or view unless explicitly asked to change that
  specific one. Flag which are affected and wait for approval.

When a task is architecturally ambiguous, present the choice:

```text
For [FEATURE], I see these approaches:

Option A: [NAME] - [one-line benefit]
  Best when: [use case]
  Trade-off: [main limitation]

Option B: [NAME] - [one-line benefit]
  Best when: [use case]
  Trade-off: [main limitation]

Which fits [the concern driving this choice]?
```

## Workflow

- Verify before claiming done: run `swift build` and `swift test` and cite the
  output. See [docs/rules/verification.md](docs/rules/verification.md).
- Commits follow Conventional Commits. One focused change per PR. A CHANGELOG
  entry for any change touching shipping source.
- No AI attribution and no em dashes in any committed text. The repo ships git
  hooks that enforce this; enable them with `git config core.hooksPath .githooks`.

## Commands

```sh
swift build
swift test
open Main.xcworkspace   # run the SwiftUI or AppKit app target in Xcode
```

(The `Packages/` workspace and app targets are not committed yet; these are the
intended commands once the M0 skeleton lands. See [CONTRIBUTING.md](CONTRIBUTING.md).)
