# Contributing to Tiledown

Thanks for your interest in Tiledown. This guide covers how to set up, the
conventions the project follows, and how to land a change.

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

## Language policy

Tiledown is a **Swift** project. All engine and tooling code is Swift.

The one exception is **JavaScript**, and only where it is intrinsic to the
output: client-side tile rendering (Mermaid diagrams, charts, forms, polls) emits
HTML and JS that run in the visitor's browser. JS is allowed for that purpose and
that purpose only. It is not used for build logic, tooling, or anything that could
be Swift instead.

## Project status

Tiledown is at the documentation and design stage. The engine package is not yet
committed, so the `swift` commands below describe the intended workflow once the
package lands; they will not run against the repo until then. The architecture is
in [`docs/DESIGN.md`](docs/DESIGN.md).

## Getting started

Will require a recent Swift toolchain (Swift 6.1+). Tiledown is a monorepo: a
workspace at the root, a single `Package.swift` under `Packages/`, and `Apps/`
for app targets. Once the package is in:

```sh
cd Packages
swift build
swift test
swift run tile-down            # renders a demo page to stdout
```

Install the project git hooks once after cloning:

```sh
git config core.hooksPath .githooks
```

This wires three hooks: `commit-msg` and `pre-commit` reject forbidden style tells
(em dashes, tool-attribution) in messages and staged content, and `pre-push` runs
the style, namespacing, format, lint, build, and test gates. The same gates run in
GitHub CI (`.github/workflows/ci.yml`) as the backstop. The Swift gates are inert
until the package lands.

## Conventions

Engine and tooling code follows the conventions documented in
[`docs/CONVENTIONS.md`](docs/CONVENTIONS.md). The short version:

- Progressive architecture: simplest thing that works first; add abstraction only
  when a second real consumer exists.
- Every public type lives under a namespace that mirrors its folder; one
  non-private type per file; file named for the qualified type.
- Dependencies are injected through initialisers. No force-unwrapping in shipping
  code. Errors carry a reason and a recovery path.
- Cross-platform: the core builds on macOS and Linux. Abstract platform-specific
  dependencies behind a protocol seam.
- Tests use the Swift Testing framework and assert behaviour, not implementation.

Read the surrounding files before writing new code and match what is already
there. Consistency with existing code outranks personal preference.

## Commits

Commit messages follow Conventional Commits: `<type>(<scope>): summary`, lowercase
type, imperative mood, no trailing period, first line under 72 characters. Types:
`feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`,
`chore`.

Do not include AI attribution of any kind, and do not use em dashes in commit
messages. The installed `commit-msg` hook enforces both.

## Branches

Branch from the current tip of `main`:

```sh
git fetch origin main && git checkout -b feat/<topic> origin/main
```

Naming: `fix/<issue>-<topic>`, `feat/<topic>`, `chore/<topic>`, `docs/<topic>`,
`refactor/<topic>`.

## Pull requests

- One focused change per PR. If the diff spans two unrelated concerns, split it.
- Add a `CHANGELOG.md` entry under `Unreleased` for any change that touches
  shipping source. Docs, tests, and config changes do not need an entry.
- Run `swift build` and `swift test` and confirm both pass before opening the PR.
- Do a self-review pass on your own diff and fix what a reviewer would flag.

## Issues

For bugs, file an issue first using the bug form, then branch with the issue
number in the name. The issue is the durable record of symptom, reproduction, and
acceptance criteria.

For features, an issue is recommended when the scope is non-trivial.

## License

By contributing, you agree that your contributions are licensed under the
project's [GNU AGPL v3.0](LICENSE).
