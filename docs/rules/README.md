# Public Swift coding rules (canonical)

The canonical, scrubbed coding rules for public Swift repos. Each file is one rule
area. This is the source of truth for the public rule set; the drop-in kit at
`../../templates/public-swift-repo/` is assembled from here by
`scripts/assemble-public-template.sh`.

`CONVENTIONS.md` is the short overview; this folder is the full set. Examples use a
sample tile-based static site generator; replace the example names with your
project's when you adopt these.

## Always relevant (engine, today)

- [engineering.md](engineering.md) - the engineering bar: progressive
  architecture, impossible states unrepresentable, testable by design.
- [code-style.md](code-style.md) - namespacing discipline, file naming,
  one-type-per-file.
- [namespacing.md](namespacing.md) - caseless `enum` vs `struct` vs `class` for
  namespace anchors.
- [dependency-injection.md](dependency-injection.md) - no singletons, inject every
  collaborator through `init`, protocol seams.
- [concurrency.md](concurrency.md) - Swift 6 strict concurrency: `Sendable`,
  actors, `@MainActor`.
- [cross-platform.md](cross-platform.md) - the core builds on macOS and Linux;
  guard platform-divergent code behind a protocol seam.
- [linux-server.md](linux-server.md) - server-side operational rules for the
  `serve` command and any networking.
- [testing.md](testing.md) - Swift Testing, `@Test` / `#expect`, test isolation.
- [testing-discipline.md](testing-discipline.md) - run the suite on every code
  change; write tests where none exist.
- [verification.md](verification.md) - no completion claim without fresh command
  output.
- [systematic-debugging.md](systematic-debugging.md) - reproduce, isolate,
  explain, fix.
- [documentation.md](documentation.md) - DocC catalogs and `///` requirements.
- [file-naming.md](file-naming.md) - filename conventions.
- [folder-grouping.md](folder-grouping.md) - when to flatten one-file folders.
- [package-structure.md](package-structure.md) - workspace and package layout: one
  `Package.swift` under `Packages/`, many targets, `Apps/` for app targets.
- [package-architecture.md](package-architecture.md) - single-responsibility
  targets with unidirectional dependencies.
- [package-import-contract.md](package-import-contract.md) - per-target allowed
  imports; applies now, the engine and CLI are already two targets.
- [shared-protocols.md](shared-protocols.md) - the cross-target protocol seam.

Open decisions live in [docs/decisions/](../decisions/).

## Git and process

- [commits.md](commits.md) - Conventional Commits format.
- [git-discipline.md](git-discipline.md) - issues, labels, PRs, branches, commits,
  remotes.

## The planned native macOS and iOS editor

- [views.md](views.md) - SwiftUI view architecture and identity.
- [view-models.md](view-models.md) - ViewModel responsibilities and patterns.
- [components.md](components.md) - the component system.
- [colors.md](colors.md) - the color system.
- [fonts.md](fonts.md) - font registration in SPM packages.
