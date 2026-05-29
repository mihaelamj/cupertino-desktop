# Code style: namespacing and structure

The operational namespacing discipline for TileKit: folder mirroring, file naming, anchor placement, one-type-per-file, reserved names, namespace-vs-module collisions.

Swift does not have true namespaces, so we simulate them with root types and extensions.

For the narrower question "should the anchor be `enum`, `struct`, or `class`?", see [namespacing.md](namespacing.md) (the type-choice canonical rule). This file covers the broader operational discipline.

## Namespacing discipline (mandatory)

**Every public type lives under a struct or enum namespace that mirrors its folder on disk.** No public type stays at file scope. The qualified name carries module + folder + role; reading `Module.Sub.Leaf` should be enough to know where the type lives and what it does.

This applies to every Swift project. The TileDown-style root + sub-namespace pattern below is one specific instance of this discipline.

### Core rules

1. **No exceptions.** Every `public struct / enum / class / actor / protocol` declared at file scope MUST be wrapped in an `extension <Namespace> { ... }` block (or declared inside a nested type). Free-standing top-level public types are not allowed.

2. **Mirror the folder.** When a folder `Sources/Foo/Bar/` holds a type `X`, the type lives at `Foo.Bar.X`. The namespace tree is a literal reflection of the file system tree.

3. **No name repetition.** When the parent namespace already supplies a word, drop it from the type's bare name. Names should not carry redundant context.

   | Before | After | Reason |
   |---|---|---|
   | `TileError` | `Tile.Error` | parent says `Tile` |
   | `RenderProgress` | `Render.Progress` | parent says `Render` |
   | `ParserToken` | `Parser.Token` | parent says `Parser` |
   | `BuildCommand` | `Build.Command.Run` | both `Build` and `Command` are supplied |
   | `SiteBuildCommand` | `Build.Command.Site` | drops `Build` AND `Command` |

4. **Subnamespace anchor.** Each subnamespace MUST be declared exactly once in a single anchor file (typically `<Sub>.swift` next to its sibling subnamespaces). Empty enums are the canonical form. The root namespace file is a *map*, not an implementation.

5. **Concrete types via extensions.** Types implement via `extension Namespace.Sub { public struct/enum/class/actor/protocol X { ... } }`. Conformances (`Codable`, `Sendable`, `Identifiable`, etc.) MAY be separate extensions on the qualified path: `extension Namespace.Sub.X: Codable { ... }`.

6. **`public extension` for protocol defaults.** Default-implementation extensions on a nested protocol use the qualified path: `public extension Module.Sub.MyProtocol { func defaultImpl() { ... } }`. Bare `extension MyProtocol` no longer resolves once the type is nested.

### Cross-cutting namespaces

Some concepts span multiple modules, e.g. *Tile* touches parsing, rendering, indexing, and formatting. When the cross-cutting concept is more semantically primary than the per-module organisation, lift the related types into a cross-cutting namespace **with a sub-namespace per source module**:

```swift
Tile
├─ Parse         (was Parse.TileParser)
│  └─ Parser
├─ Core          (was Core.TileCatalog etc.)
│  ├─ Catalog
│  ├─ Entry
│  └─ Statistics
├─ Render        (was Render.TileRenderService etc.)
│  ├─ Service
│  ├─ Query
│  └─ Result
├─ Index         (was the entire TileIndex SPM target)
└─ Format        (was Format.Tile*)
   ├─ Markdown
   ├─ JSON
   └─ Text
```

The sub-namespace name preserves provenance (which module the type used to live in). The cross-cutting namespace lives in the lowest common ancestor that every consumer already imports, typically a `Shared*` foundation target.

### Command-tool pattern

Subcommand types in CLI binaries (`AsyncParsableCommand` conformers) nest under a `Command` namespace:

```swift
// In the main CLI binary:
enum Command {}                  // declared in Commands/Command.swift
extension Command {
    struct Build: AsyncParsableCommand { ... }    // was BuildCommand
    struct Serve: AsyncParsableCommand { ... }    // was ServeCommand
    struct Watch: AsyncParsableCommand { ... }    // was WatchCommand
}

// In sibling CLI binaries, the outer namespace is the tool's own name:
enum Release {
    enum Command {}             // declared in ReleaseTool/Release.swift
}
extension Release.Command {
    struct Bump: AsyncParsableCommand { ... }      // was BumpCommand
    struct Database: AsyncParsableCommand { ... }  // was DatabaseReleaseCommand
}
```

The root dispatcher (the `@main AsyncParsableCommand` that holds `subcommands: [...]`) stays at file scope; it's not a subcommand. `swift-argument-parser` conformance stays on every struct.

### Namespace-vs-module collisions

When a nested namespace shares a name with an imported SPM target (e.g. the CLI declares `Command.Render` but also imports the `Render` SPM target), Swift's name lookup checks enclosing types before imported modules. Bare `Render.Type` inside any `extension Command { ... }` scope resolves to the local subcommand struct, not the module.

Fix: declare **one module-internal typealias** in a small alias file at the consuming target's root, pinning the SPM target under a renamed identifier:

```swift
// Sources/CLI/RenderModuleAlias.swift
import Render
typealias RenderModule = Render
```

Then call sites in the affected target write `RenderModule.Type` for module-level references. One declaration covers every consumer in the target; no per-file typealiases.

Same pattern for any `Module / Namespace` name clash.

### Same leaf name under different roots

Two unrelated namespaces under different roots MAY share a leaf name. Example: `Parser.CSV` (top-level format-parser namespace holding `CSV`/`HTML`/`XML`/etc.) plus `Core.Parser.Encoding` (parser-primitives sub-namespace under `Core`). Swift resolves on the fully-qualified path; the compiler never gets confused. The only friction is the cognitive cost at the callsite of remembering which root a reader means.

When this emerges, prefer **renaming one of the two roots** to a more specific concept (e.g. `Core/Parser/` to `Core/Parsing/` so the leaf names diverge) over inserting per-file disambiguating typealiases. Typealiases create a per-target rename that has to be maintained; folder renames are cheap once-only moves.

If renaming is genuinely not worth it (e.g. the two roots have stable independent meanings and most readers never see them in the same file), the collision is acceptable. The case is *cognitive*, not *syntactic*.

### Reserved names

- **`Protocol`** is a reserved member on every type expression (the metatype literal `T.Protocol`). A namespace enum cannot be named `Protocol`. Use `Protocols` (plural), `Wire`, or `Spec`. The folder on disk MAY still be named `Protocol/`; only the Swift-level namespace name diverges.
- **`Error`** as a nested type name collides with `Swift.Error` in `catch` patterns. Choices:
  - Keep as a sibling: `Module.<Type>Error` (e.g. `Tile.RenderError`)
  - Or nest with full Swift.Error qualification: `extension Module.<Type> { public enum Error: Swift.Error, ... }`, and use `catch let error as Module.<Type>.Error` explicitly at call sites
- **Self-naming sub-namespace conflict.** If a sub-namespace and the type inside share a name (e.g. `Transport` namespace holding a `Transport` protocol), rename the inner type (`Transport.Channel`, `Transport.Service`). Don't try `Transport.Transport`.

### Multi-target and mono-repo behaviour

Multiple SwiftPM targets MAY contribute additional concrete types under the same shared root namespace via extensions:

```text
TileDown.Parser.Model.Token          // from TileKitCore
TileDown.Generator.Command           // from TileKitCLI
TileDown.Parser.Scanning.Scanner     // from TileKitTools
```

Targets MUST NOT redefine conflicting namespace trees, and the root namespace meaning MUST be identical across all modules.

## Root + sub-namespace pattern (TileDown style)

This is one specific instance of the namespacing discipline above. Use it as the canonical example when designing a new project's namespace tree.

A project MAY use a hierarchical namespace tree where:

- A root namespace enum defines the domain
- Sub-namespaces are nested enums inside it
- All concrete types live in extensions on the leaf namespace

### Root namespace with nested sub-namespaces

The root namespace file MUST define the full tree of namespace enums, and MUST contain only namespaces (no concrete types).

Example:

```swift
/// Root namespace for all TileDown types across all modules
public enum TileDown {
    /// Model types for tile metadata and structure
    public enum Model {}

    /// Parser types for processing tiles
    public enum Parser {
        /// Model types for parsing (tokens, transformations, etc.)
        public enum Model {}

        /// Metadata parsing types
        public enum Metadata {}

        /// Resolution and variable context types
        public enum Resolution {}

        /// Scanning and tile discovery types
        public enum Scanning {}

        /// Tree building and hierarchy types
        public enum Tree {}

        /// Content and variable parsing types
        public enum Content {}
    }

    /// Generator types for writing output
    public enum Generator {}
}
```

Rules:

- Root namespace = one file (e.g. `TileDown.swift`)
- Only namespace enums inside (no concrete logic)
- No stored properties, no methods, no initializers, no nested concrete types
- Doc comments are allowed and encouraged

This file is a map, not an implementation.

### Concrete types via extensions on leaf namespaces

Concrete model, parsing, resolving, generating, or utility types MUST be implemented using `extension` on the leaf namespace where the type belongs.

Example:

```swift
// Token.swift
import Foundation
import Models

extension TileDown.Parser.Model {
    /// Represents a parsed piece of tile content
    public enum Token: Equatable, Sendable {
        case text(String)
        case variable(VariableToken)
    }
}

extension TileDown.Parser.Model.Token: CustomStringConvertible {
    public var description: String {
        switch self {
        case .text(let str): return "Text(\"\(str)\")"
        case .variable(let token): return "Variable(\(token))"
        }
    }
}
```

Rules:

- Implementation and conformances MUST be extensions
- Type lives under the correct semantic path, e.g.:
  - `TileDown.Model`
  - `TileDown.Parser.Model`
  - `TileDown.Parser.Metadata`
  - `TileDown.Generator`
- Conformances (`Codable`, `Sendable`, `CustomStringConvertible`, etc.) MAY be separate extensions

### File layout for TileDown-style namespacing

Files SHOULD be placed to reflect the namespace tree. Two equivalent conventions:

**Folder-based approach**: the folder tree mirrors the namespace tree, one file per leaf type:

```text
TileDown/
    TileDown.swift                       // namespace anchor: public enum TileDown {}
    Parser/Model/Token.swift             // extension TileDown.Parser.Model { public enum Token {} }
    Parser/Scanning/Scanner.swift        // extension TileDown.Parser.Scanning { public struct Scanner {} }
    Generator/Writer.swift               // extension TileDown.Generator { public struct Writer {} }
```

**`<Namespace>.<Type>.swift` approach**: flat folder, file name encodes the namespace path with dots:

```text
TileDown.swift                              // namespace anchor: public enum TileDown {}
TileDown.Parser.Model.Token.swift           // extension TileDown.Parser.Model { public enum Token {} }
TileDown.Parser.Metadata.Header.swift       // extension TileDown.Parser.Metadata { public struct Header {} }
```

Within a single SPM target, pick ONE pattern and stay with it.

### File-naming rule for namespace extensions (mandatory)

When a file contains `extension <Namespace> { public X <Type> { ... } }`, the file name MUST be `<Namespace>.<Type>.swift`, the dot-separated qualified path of the type. This applies regardless of whether the type would also be unique without the `.<Type>` suffix.

Examples:

- `extension Indexer { public enum TilesService { ... } }` to `Indexer.TilesService.swift`
- `extension Indexer { public enum PackagesService { ... } }` to `Indexer.PackagesService.swift`
- `extension Tile.Index { public actor Builder { ... } }` to `Tile.Index.Builder.swift`
- `extension Core.Protocols { public protocol ContentFetcher { ... } }` to `Core.Protocols.ContentFetcher.swift`

Dots match the Swift qualified name exactly: `Tile.Index.Builder` lives at `Tile.Index.Builder.swift`. The older `<Namespace>+<Type>.swift` convention (with a `+` separator) is deprecated; new files MUST use dots, and pre-existing `+` files SHOULD be renamed when touched.

Why uniformity even when not strictly needed:

- The namespace path is visible from the file listing without opening any file.
- Adding a second type to the same namespace later doesn't require renaming the first.
- Search and tooling (Xcode's filter, `rg --files-with-matches`, the project navigator) work as a flat index on the qualified path.

The only file in a namespace folder that does NOT carry `.<Type>` is the **namespace anchor**:

- `TileDown.swift` declaring `public enum TileDown { /* sub-namespaces */ }`
- `Tile.swift` declaring `public enum Tile { public enum Parse {} public enum Core {} ... }`

Anchor files contain only namespace enums, never concrete types.

#### Namespace anchor file placement (mandatory)

The anchor file for a namespace MUST live at the **root of the namespace's owning folder**, not buried in a sub-target folder.

When `<Namespace>` is the umbrella for several SPM sub-targets that each live in a child folder, the anchor file `<Namespace>.swift` goes at the parent folder root, alongside (not inside) the sub-target folders. The sub-target whose SPM `path:` spans the parent folder picks up the anchor file as part of its sources.

Concrete example, a `TileKit` namespace umbrella:

```text
Sources/TileKit/
├── TileKit.swift          // namespace anchor: extension TileKit { ... }      <-- AT ROOT, not Core/TileKit.swift
├── Client/                // TileKitClient SPM target
├── Core/                  // TileKitCore SPM target (path includes ../TileKit.swift)
│   ├── Protocol/
│   ├── Server/
│   └── Transport/
├── SharedTools/           // TileKitSharedTools SPM target
└── Support/               // TileKitSupport SPM target
```

The TileKitCore target's `Package.swift` entry uses `path: "Sources/TileKit"` with `exclude: ["Client", "SharedTools", "Support"]` so it picks up the anchor file plus the `Core/` subtree. Every sibling target (Client, SharedTools, Support) depends on TileKitCore in production, so the `TileKit` namespace anchor reaches them through that dep.

Why this matters:

- Reading the file listing immediately tells you "TileKit is the umbrella here": the anchor sits visually at the top.
- Moving an anchor into `Core/TileKit.swift` (or any other sub-target folder) hides the umbrella relationship behind one extra `cd` and one extra mental indirection.
- The same parent-folder pattern applies to `Shared` (anchor at `Sources/Shared/Shared.swift`, not `Sources/Shared/Constants/Shared.swift`), and to any future grouped target family.

For cross-cutting namespaces (e.g. a `Tile` namespace that touches multiple SPM targets and is not owned by any single folder), the anchor lives in the lowest-leaf foundation target that every consumer reaches, AT THAT TARGET'S FOLDER ROOT, not in a sub-folder: e.g. `Sources/Shared/Tile.swift` (alongside `Shared.swift`), not `Sources/Shared/Constants/Tile.swift`.

#### One non-private type per file (mandatory)

Each file contains **exactly one** `public`, `package`, or `internal` (default-visibility) top-level type. Private/fileprivate helper types MAY co-locate with the main type when they exist solely to support it. This is enforced by `scripts/check-namespacing.sh` locally (pre-push) and in CI; see [verification.md](verification.md).

Strict reading:

- A file `Foo.Bar.X.swift` declares exactly one of `extension Foo.Bar { public enum X { ... } }`, `... public struct X`, `... public protocol X`, `... public actor X`, `... public class X`, etc.
- Inner / nested types DECLARED INSIDE the main type (`extension Foo.Bar.X { public enum Error { ... } }` or `extension Foo.Bar.X { public struct Stats { ... } }`) MAY live in the same file. Each nested type also goes in its own file once it grows beyond ~50 lines or gains independent reuse.
- File-private decode-only Codable models, internal-detail helper structs, etc. (anything you'd mark `private` or `fileprivate` so it cannot leak), MAY share the file. Mark them with the access modifier explicitly; don't rely on default-internal access.

Anti-pattern to avoid:

```swift
// Bad: Core.Parser.HTML.swift declares two unrelated public types
extension Core.Parser {
    public struct HTML: ContentTransformer { ... }
}

extension Core.Parser {
    public struct XML: ContentTransformer { ... }   // <-- belongs in its own file Core.Parser.XML.swift
}
```

Fix:

```swift
// Core.Parser.HTML.swift: one type
extension Core.Parser {
    public struct HTML: ContentTransformer { ... }
}

// Core.Parser.HTML.Error.swift: nested type that grew (or extract inline if small)
extension Core.Parser.HTML {
    public enum Error: Swift.Error { ... }
}

// Core.Parser.XML.swift: sibling type, own file
extension Core.Parser {
    public struct XML: ContentTransformer { ... }
}
```

Acceptance check:

```bash
for f in $(find Packages/Sources -name "*.swift"); do
    count=$(grep -cE "^(public |package |internal )?(actor|struct|enum|protocol|class|final class) [A-Z]" "$f")
    [ "$count" -gt 1 ] && echo "$count $f"
done
```

Output MUST be empty; any reported file is a violation. Add the `private`/`fileprivate` modifier to helper types so they drop out of the count, or split the file.

#### File renames ship in their own PR

Type renames (`TilesIndexerService` to `Indexer.TilesService`) and file renames (`TilesIndexerService.swift` to `Indexer.TilesService.swift`) are different PRs. Type-rename first; easier review surface, can revert without filesystem churn. File-rename follows once the type change is settled.
