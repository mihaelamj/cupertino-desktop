# Agent Guide

Guidance for anyone (human or coding agent) writing code in Tiledown.

## Rule loading (read this first)

At the start of a session, read [docs/rules/README.md](docs/rules/README.md) and
the rules it marks as always relevant. Then confirm you have done so by replying
with the token `rules-loaded`, and name the rule files that apply to the task at
hand. If you cannot name them, you have not loaded the rules. The mechanical gates
(hooks and CI) enforce the checkable rules regardless, but the judgment rules
depend on you having read them.

## What Tiledown is

A tile-native static site generator. The canonical document is a tree of typed
**tiles** (not Markdown), rendered to static HTML for publishing to GitHub Pages.
The engine library is `TileKit`; the CLI is `tile-down`. The engine targets macOS
and Linux. A native macOS and iOS editor app over the same tile model is a separate,
future concern. See [docs/DESIGN.md](docs/DESIGN.md).

## Language policy

Swift for everything. The only exception is JavaScript, and only where it is
intrinsic to the output: client-side tiles (charts, diagrams, forms, polls) emit
HTML and JS that run in the visitor's browser. JS is never used for build logic or
tooling.

## Rules

Conventions live in [docs/rules/](docs/rules/). Read the surrounding files before
writing code and match what is there.

**Read these for any change to engine or tooling code:**

- [docs/rules/engineering.md](docs/rules/engineering.md)
- [docs/rules/code-style.md](docs/rules/code-style.md) and
  [docs/rules/namespacing.md](docs/rules/namespacing.md)
- [docs/rules/dependency-injection.md](docs/rules/dependency-injection.md)
- [docs/rules/concurrency.md](docs/rules/concurrency.md)
- [docs/rules/cross-platform.md](docs/rules/cross-platform.md)
- [docs/rules/testing.md](docs/rules/testing.md) and
  [docs/rules/verification.md](docs/rules/verification.md)

**Load the rest on demand**: testing-discipline, documentation, linux-server,
point-free-dependencies, systematic-debugging, file-naming, folder-grouping,
commits, git-discipline, and (for the planned native app) views, view-models,
components, colors, fonts, and (if Tiledown becomes multi-package) the package
architecture set. The index is [docs/rules/README.md](docs/rules/README.md).

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
  specific one. Flag which are affected and wait for approval. (Inert until the
  native app exists.)

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
swift run tile-down
```

(The engine package is not yet committed; these are the intended commands once it
lands. See [CONTRIBUTING.md](CONTRIBUTING.md).)
