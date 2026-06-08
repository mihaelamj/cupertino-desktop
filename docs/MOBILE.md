# Mobile (iOS) path and the CupertinoDataKit data-API extraction

How the iPhone and iPad variants reach the documentation corpus, and the layering
that gets them there without depending on the `cupertino` repository.

See also [DESIGN.md](DESIGN.md) (the backend seam and the macOS subprocess path),
[PROTOCOL.md](PROTOCOL.md) (the per-verb mapping into `AppModels`), and
[decisions/fixed-native-ui-matrix.md](decisions/fixed-native-ui-matrix.md) (the fixed
native UI matrix).

## Why iOS is different

The macOS app reaches cupertino by spawning a `cupertino serve` subprocess and talking
to it over MCP (the `Backend.LocalSubprocess` adapter). **iOS cannot spawn a
subprocess**, so that path does not apply. The iOS variants must run a read
implementation **in process**.

The constraint that shapes everything below: **do not depend on the `cupertino`
repository on iOS.** cupertino is a server and CLI built around an FTS-SQLite corpus
with an enriched structured front; it is not an iOS-shippable library, and pulling it
in as a dependency is the wrong move. Instead we **extract its read API as a protocol
package** and implement that protocol ourselves for the embedded path, the same
playbook used for [`SwiftMCPCore`](https://github.com/mihaelamj/SwiftMCPCore) and
[`SwiftMCPClient`](https://github.com/mihaelamj/SwiftMCPClient).

## The layering

```
Cupertino corpus               downloaded or bundled data, opened only by Cupertino code
  │
CatalogStore                   where the corpus comes from (bundled vs downloadable)
  │
CupertinoDataKit               the read/data API, PROTOCOLS ONLY. cupertino-owned, external.
  │   conformed two ways, both extracted from cupertino, both cupertino-owned/published:
  ├── cupertino (server)       the full FTS-SQLite engine; the macOS app reaches it over MCP.
  └── CupertinoDataEngine      cupertino's read engine extracted and made iOS-buildable; a
  │                            separate external package the iOS app embeds in process.
  │
MobileData                     desktop-side wiring only: resolves the local corpus for
  │                            CupertinoDataEngine and surfaces it through the backend adapter.
  │
LocalEmbeddedBackend           maps CupertinoDataEngine results into AppModels.
  │
Backend.Documentation          our domain seam (AppModels), unchanged. Features and UI
                               depend only on this and never see CupertinoDataKit or SQLite.
```

Two layers are extracted from cupertino into cupertino-owned external packages: the
**`CupertinoDataKit`** contract and the **`CupertinoDataEngine`** implementation. This app
owns only the thin parts (`CatalogStore`, `MobileData`, `LocalEmbeddedBackend`). Everything
above the `Backend.Documentation` seam is identical to the macOS path; only the *locality*
of the backend differs (out-of-process subprocess on macOS, in-process embedded on
iPhone/iPad and Qt desktop targets).

## CupertinoDataKit

A **public, shareable, cupertino-specific, protocols-only** package: cupertino's
data/read API expressed as protocols plus the option and result value types. It is
Foundation-only, cross-platform (including iOS), and contains **zero implementation**,
no SQLite, no engine.

It is named for cupertino on purpose. This is the opposite choice from the MCP packages
(`SwiftMCPCore` / `SwiftMCPClient`), which were neutral-named because MCP is a general
standard. `CupertinoDataKit` is cupertino's **specific** command surface (`list_frameworks`,
`read_document`, `search_docs`, `search_symbols`, `inheritance`, and so on, with
cupertino's own options and result shapes), so it carries a cupertino name.

It is conformed **two ways, both extracted from cupertino and both cupertino-owned**:

- **cupertino (server)** conforms to it with the full FTS-SQLite engine over the full
  corpus. The macOS desktop reaches that implementation over MCP through the subprocess.
- **`CupertinoDataEngine`** is cupertino's read engine **extracted and made
  app-embeddable**, a separate external package that conforms to `CupertinoDataKit` and
  runs in process. The iPhone/iPad apps embed it; the Linux and Windows Qt apps use the
  same local embedded family. The desktop app does not reimplement the engine; it consumes
  cupertino's.

Neither depends on the other; both depend only on the `CupertinoDataKit` protocols.
**cupertino owns both `CupertinoDataKit` and `CupertinoDataEngine`:** they are cupertino's
API surface and engine, so cupertino creates, publishes, and tags both repositories, and is
the source of truth for the shapes. This app is a consumer; it depends on them by version,
never the reverse. The contract shapes are agreed with cupertino before the repo is cut,
the same gate used for the MCP extractions. `CupertinoDataEngine` is the larger lift,
decoupling the read engine from cupertino's server, CLI, and indexer with no iOS-hostile
dependencies.

`CupertinoDataKit` is not new types. cupertino's read contract already lives inside its
`SearchModels` target as the `Search.Database` protocol and its value types. cupertino
**moves** that whole contract out into `CupertinoDataKit` as the single source of truth and
re-exports it from `SearchModels` (the `SwiftMCPCore` carve-out pattern), so there is one
definition, never a mirror kept in sync by a bridge. The carve-out is cupertino's to
execute; this app only consumes the published package, and **the package itself is the
definitive statement of the shapes** (the exact protocol and value types are finalized
there, not in any prose here).

**v0.1.0 = cupertino's full read contract**, the entire `Search.Database` protocol (search,
read, list-frameworks, document-count, disconnect, plus the symbol / inheritance /
availability surface) and all its value types, moved as-is. It is the full surface rather
than a trimmed subset on purpose: one package to test in isolation and to extend in one
place, with no drift between a public subset and an internal protocol.

## MobileData

The desktop-side wiring for the embedded path, and the only part of it this app owns. It
does **not** reimplement the engine; it embeds the external `CupertinoDataEngine`, feeds it
a database via a `CatalogStore` (bundled or downloaded), and surfaces it through
`LocalEmbeddedBackend`, which maps the `CupertinoDataKit` results into `AppModels`. The
heavy lifting (the FTS-SQLite engine) lives in cupertino's external package; only corpus
delivery and the adapter live here.

## Relationship to the existing design

This supersedes the note in [DESIGN.md](DESIGN.md) that the embedded path would depend on
the `cupertino` package via a `CupertinoUpstream` symlink. The embedded path does not depend
on the cupertino repository at all; it depends on the extracted `CupertinoDataKit` protocols
and `CupertinoDataEngine` package, both versioned, and adds only its own `MobileData` wiring.

The two backend localities remain peers over the one `Backend.Documentation` seam:

- `Backend.LocalSubprocess` (macOS): drives the Homebrew `cupertino` binary over MCP.
- `Backend.LocalEmbedded` (iPhone/iPad/Linux/Windows): embeds `CupertinoDataEngine` in
  process via local catalog wiring.

## UI variants

The iOS UI ships as distinct native variants per the eight-variant plan in
[DESIGN.md](DESIGN.md): `ShelliPhoneSwiftUI`, `ShelliPhoneUIKit`, `ShelliPadSwiftUI`,
`ShelliPadUIKit`. iPhone and iPad are deliberately different presentations, not one
size-class-adaptive shell. All of them bind the same framework-agnostic view models
(for example `Feature.FrameworkBrowser.ViewModel`) and the same `Backend.Documentation`
seam, so the only variables are device idiom and UI framework. They are built in
parallel for the same reason the macOS shells are: to let the right shared seam reveal
itself at the second consumer (see the seam-discovery note in [DESIGN.md](DESIGN.md)).

## Status

- **`CupertinoDataKit` published and consumed.** v0.1.0 is on GitHub (cupertino-owned,
  tagged); this app depends on it by version and never on the `cupertino` repo. The
  embedded adapter `Backend.LocalEmbedded` maps injected `Search.DocumentReading`,
  `Search.SymbolReading`, and `Sample.Index.Reader` slices into `AppModels`. Package
  search remains unsupported on the embedded path until CupertinoDataKit publishes a
  package-reader protocol.
- **Two adaptive mobile apps ship today** over that seam as legacy current state:
  `CupertinoMobileSwiftUI` (over `ShellSwiftUI`) and `CupertinoMobileUIKit` (over
  `ShellUIKit`), each handling iPhone and iPad idioms. This is not the final design:
  the accepted target is four distinct iPhone/iPad shells and app schemes, per
  [UI-DESIGN.md](UI-DESIGN.md) and
  [decisions/fixed-native-ui-matrix.md](decisions/fixed-native-ui-matrix.md).
- **`CupertinoDataEngine` (the real embedded read engine): designed and accepted, but
  implementation deferred to a future cupertino release** (maintainer decision, design
  doc in cupertino PR #1186; read/write split via a Bridge, cross-source via a Composite
  over the contract types, read-only mode, sheds SwiftSyntax). When it ships it is just a
  second implementation of the same reader contracts, added behind
  `MobileBackend.live(dataSource:symbolReader:sampleReader:)` with no adapter change.
- **Until then the mock is the iOS data source.** `MobileBackend.mock()` injects
  `MobileBackend.MockReader`, which is driven by `Resources/MockCorpus.json`: real
  framework names, real document counts, and real Apple documents (full page bodies, not
  just abstracts) captured verbatim from the cupertino index. It honours the answerable
  search options (source, framework, query, the per-platform-minimum floor, and limit). The
  macOS subprocess (MCP) path is unaffected by all of this.
