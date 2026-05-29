# Swift namespaces via enums or structs, canonical rule

Single-page rule for picking the namespace-anchor type in TileKit code: when the anchor is `Foo`, should it be `enum Foo`, `struct Foo`, or `class Foo`?

Companion to [code-style.md](code-style.md), which covers the broader namespacing discipline (folder mirroring, file-naming convention, anchor file placement, one-type-per-file). This file answers the narrower type-choice question.

## TL;DR

**Default: caseless `enum`.** Use `struct` only when the type also represents a value. Never `class`.

```swift
// Pure namespace, caseless enum.
public enum Shared {}
extension Shared {
    public enum Constants {}      // nested namespace
    public enum Configuration {}  // nested namespace
}

// Value type that also acts as a namespace for its own helpers, struct.
public struct URL: Sendable, Equatable {
    public let absoluteString: String
    public init(_ s: String) { self.absoluteString = s }

    public struct Components { /* nested type */ }
    public static let placeholder = URL("about:blank")
}
```

## Why caseless `enum`?

A namespace anchor exists to hold nested types and static members. It should be:

1. **Uninstantiable.** `let x = Shared()` must not compile. A caseless enum can't be instantiated because there are no cases to construct it from. A `struct` *can* be instantiated (Swift synthesises `init()` for an empty struct, yielding a zero-sized instance); a `class` even more so. Only `enum` gives uninstantiability by construction, with no extra code required.
2. **Free of ARC and runtime overhead.** A `class` carries a refcount header even when empty. A `struct` carries no header but is still a value. A caseless `enum` has no runtime footprint.
3. **Cleanly extensible.** `extension Shared { ... }` adds nested types from any file. Standard Swift practice; works identically across enum, struct, and class.
4. **Idiom recognised by the Swift community since 2015.** Reading `enum Foo {}` tells the next reader "this is a namespace" immediately. Reading `struct Foo {}` is ambiguous: could be a namespace, could be an empty value.

The Swift Standard Library uses `enum` for the same purpose. `enum Result` and `enum Optional` are case-bearing, but the pure-namespace pattern in user libraries follows this rule.

## When to use `struct`

Use `struct` for the namespace anchor **only** when the type:

- Holds **value-typed state** the consumer cares about, AND
- Also serves as the container for nested types or static helpers.

```swift
// The type represents a value (the resolved paths) AND holds nested helpers
// (Paths.live()). Struct is correct here.
public struct Paths: Sendable {
    public let baseDirectory: URL
    public let docsDirectory: URL
    // ... derived URLs ...

    public static func live() -> Paths { /* ... */ }
}
```

If the namespace has no state and no instances, `enum` is correct. If it represents a value, `struct` is correct. Never both; split into a struct value plus an enum namespace if both roles are needed.

## When to use `class`

**Never**, for namespacing. Class adds:

- Refcounted heap allocation (even for empty classes, Swift still emits an instance header).
- A deinit slot.
- Inheritance complications (`open` vs `final`).

A namespace doesn't need any of that. If you're tempted to use a class for "shared mutable state in a namespace," you actually want an **actor** or a struct value injected through DI, not a namespace anchor.

**When to reach for `actor` instead of `enum` namespace.** All three of these must hold: (a) the state is mutable, (b) the state is genuinely shared across concurrent contexts (multiple tasks read or write it), (c) the access pattern fits serial isolation. If any one is false, the right answer is a struct value injected through `init`, not a namespace anchor and not an actor.

## What about protocols?

A `protocol` is not a namespace anchor. Protocols name a contract; namespaces hold types and static members. The two roles don't overlap.

A protocol MAY live inside a namespace:

```swift
public enum Logging {}
extension Logging {
    public protocol Recording: Sendable { ... }
}
```

The namespace is still `enum Logging`. The protocol is a nested type. For cross-target seams, the protocol lives in a foundation-only `*Models` target (cross-package coupling via protocols, not concrete imports). The composition root wires the concrete conformer.

## Anti-patterns

### `struct` for a pure namespace

```swift
// Don't. Shared() is constructible even though it has no meaning.
public struct Shared {}

let s = Shared()  // compiles, allocates nothing, but is meaningless
```

Use `enum Shared {}` instead.

### `enum` with a private initialiser (the pre-2015 workaround)

```swift
// Don't. Caseless enum already prevents instantiation; no init needed.
public enum Shared {
    private init() {}  // unreachable; clutters the API
}
```

Just `public enum Shared {}`. No init.

### Stateless `class` as namespace

```swift
// Don't. Class adds ARC overhead for zero benefit.
public final class Shared {
    public static let constants = Constants()
}
```

Use `enum Shared {}` plus extensions.

### Nesting a `struct` that's only a namespace inside a value type

```swift
// The outer struct is a value; the nested "namespace" struct adds no value
// but is constructible.
public struct Configuration {
    public let renderer: Renderer

    public struct Constants {           // nested but a namespace, should be enum
        public static let fileName = "config.json"
    }
}
```

Inner type should be `public enum Constants` since it carries no state.

## Singular vs plural for kind-group namespaces

When a namespace holds N sibling implementations of one concept (e.g. several format parsers, several content fetchers, multiple model types), either singular (`Parser.CSV`, `Fetcher.Remote`, `Model.Tile`) or plural (`Parsers.CSV`, `Fetchers.Remote`, `Models.Tile`) is correct. Pick one per project and stay with it. Apple's Combine uses plural (`Publishers.Map`, `Subscribers.Sink`); some projects pick singular to match folder-name conventions. The rule is intra-project consistency, not the choice itself.

The one exception is `Protocol` (singular). Swift treats `T.Protocol` as a reserved metatype member on every type expression, so a namespace literally cannot be named `Protocol`. MUST be `Protocols` plural OR a semantic rename (`Wire`, `Spec`) regardless of the project's singular-vs-plural default. See `Reserved names` in [code-style.md](code-style.md).

## When nesting

Nest a namespace inside another namespace by extending:

```swift
public enum Shared {}
extension Shared {
    public enum Constants {}
    public enum Configuration {}
}
extension Shared.Constants {
    public enum FileName {
        public static let renderDatabase = "render.db"
        public static let metadata = "metadata.json"
    }
}
```

Each level of nesting stays a caseless `enum`. File layout: one nested namespace per file, named `Shared.Constants.FileName.swift`, etc. Folder layout mirrors the namespace tree:

```text
Sources/SharedConstants/
├── Shared.swift                       # public enum Shared {}
├── Constants/
│   ├── Shared.Constants.swift         # public enum Shared.Constants {}
│   ├── Shared.Constants.FileName.swift
│   └── Shared.Constants.BaseURL.swift
```

## Why the file-rename convention matters

When the namespace is `Shared.Constants.FileName`, the file should be `Shared.Constants.FileName.swift`. Reasons:

1. `git grep "Shared.Constants.FileName"` finds both the declaration site (via filename) and usages (via type reference) in one search.
2. Re-namespacing the type (moving `FileName` under a different parent) becomes a single `git mv`.
3. Folder structure mirrors the namespace tree without a separate map file.

See [code-style.md](code-style.md) for the full file-naming rule.

## Anchor file convention

Every public namespace gets a single declaration file:

```swift
// Shared.swift
public enum Shared {}
```

```swift
// Shared.Constants.swift
extension Shared {
    public enum Constants {}
}
```

```swift
// Shared.Constants.FileName.swift
extension Shared.Constants {
    public enum FileName {
        public static let renderDatabase = "render.db"
        // ...
    }
}
```

Anchor files contain ONLY the `extension X { public enum Y {} }` line, no implementation. Implementation lives in sibling files inside the same nested namespace. The anchor plus folder convention makes the namespace tree mechanically discoverable: `find Sources/SharedConstants -name "Shared.*.swift"` lists every public-anchor file.

## Apple precedent

- **Swift Standard Library:** `enum Never`, `enum CommandLine`, `enum FloatingPointRoundingRule`, `enum ProcessInfo.ThermalState`. Caseless enums for both true-namespace types (`CommandLine`) and case-bearing enums.
- **Foundation:** `struct URL`, `struct UUID`, `struct Data`. Structs because they carry value state. Their nested types (`URL.ResourceValues`) are also structs because they carry state. `URLSession` is a class because it owns resources.
- **SwiftUI:** `View` is a protocol; conforming types are structs because they're value-types describing UI. `enum Edge`, `enum Axis` are case-bearing enums.

The cross-cutting rule: **type follows function.** Namespace, `enum`. Value, `struct`. Reference identity or shared mutable state, `class` or `actor`.

## Migration tip

If a codebase has `struct Shared {}` or `class Shared {}` as a namespace, the simple cases are mechanical:

```bash
# Find every empty-body declaration
git grep -l 'struct Shared {}\|class Shared {}'

# Replace
sed -i.bak 's/public struct Shared {}/public enum Shared {}/' <files>
sed -i.bak 's/public class Shared {}/public enum Shared {}/' <files>
```

**The regex handles the empty-body case only.** Declarations with conformances (`public struct Shared: Sendable {}`), inheritance clauses, or any body content will not match. Do those rewrites by hand, one at a time, after auditing the existing conformances and members. Don't sed-blast complex declarations; the result is too easy to corrupt silently (a missed conformance, a body line left behind referring to `self`, etc.).

Build and tests verify the safe cases: anything that was constructing the empty struct or class will fail to compile, and those callsites were wrong anyway.

## Reference

- Swift API Design Guidelines: https://swift.org/documentation/api-design-guidelines/
- "Caseless enums for namespaces" idiom: Erica Sadun, 2015 (widely adopted since).

## Cross-references

- [code-style.md](code-style.md) covers the broader namespacing discipline (folder mirroring, file-naming convention, anchor file placement, one-type-per-file, reserved names, namespace-vs-module collisions). Read this file first for the anchor-type choice, then code-style.md for the operational details.
