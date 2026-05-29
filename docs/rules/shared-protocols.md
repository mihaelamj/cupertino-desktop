# Shared Protocols Target

The pattern for a single foundation-only target that holds every cross-target protocol seam. Tiledown is a monorepo from day one with many targets in one package, so the seam target applies as soon as one producer target needs to talk to another without importing its concretes. Add it when the first cross-target seam appears.

Companion to [dependency-injection.md](dependency-injection.md) and [package-import-contract.md](package-import-contract.md). The target described here is conventionally named `SharedProtocols`.

## Target regime

Across the package's targets, every internal target falls into one of two categories:

1. **Producer / feature targets** import only `SharedProtocols` plus external dependencies (Foundation, SwiftUI, Combine, third-party SPM). Their SPM `dependencies:` list is `["SharedProtocols", ...external products]` and nothing else internal.
2. **Composition root and live-writer targets** (the CLI, networking, storage, environment, and similar glue) import `SharedProtocols` plus the external framework they bridge. Their `dependencies:` list is `["SharedProtocols", ...the framework being wrapped]`. These are the only places where protocol-to-concrete glue exists.

There is no third category.

## Hard rules

1. **`SharedProtocols` has zero internal dependencies.** Its SPM `dependencies:` list is `[]`.
2. **Allowed imports inside `SharedProtocols`:** any external framework (`Foundation`, `SwiftUI`, `Combine`, a logging library, etc.). **Forbidden:** any internal package.
3. **Declarations are top-level.** `public protocol Recording`, not nested under a namespace anchor like `extension SharedProtocols { protocol Recording }`.
4. **Naming follows the domain noun form.** `Recording`, `FileSystem`, `HTTPRequester`. The protocol is the noun; the conformer is `LiveRecording`. You do not have to suffix the protocol with `-able` or `-ing`.
5. **One concept per file**, filename equal to the type name. Group related files in subfolders (`Coordinators/`, `Providers/`) when there are three or more related declarations.
6. **DEBUG-only preview implementations live here too**, as a `Preview_*_Impl` no-op shape wrapped in `#if DEBUG`.

## What goes in `SharedProtocols`

- **Protocol seams:** every protocol that exists to decouple a producer from a concrete (`Recording`, `HTTPRequester`, `FileSystem`, `UUIDProvider`, `DateProvider`, and so on).
- **Coordinator protocols** for navigation/flow when the codebase uses them.
- **Value types** that travel across targets: enums (`HTTPMethod`, `LogLevel`), small structs (`HTTPResponse`, a domain model).
- **Null implementations** (`NullRecording`, `NullHTTPRequester`) so producers can default to a no-op without importing a live writer.
- **DEBUG-only `Preview_*_Impl`** no-op conformances for SwiftUI previews and tests.

## What does NOT go in `SharedProtocols`

- **Live writers and concrete services** (`LiveRecording`, `LiveHTTPClient`, `LiveFileSystem`). These live in their own glue targets.
- **Per-capability locator protocols invented just to satisfy a DI checklist.** If the composition root can probe the environment in three lines and decide whether to register a service, do not manufacture a one-method protocol for it.

## Why

Cross-package coupling through protocols (rather than concrete imports) only works if the protocol is reachable without dragging in the rest of the producer's universe. If a protocol lives in producer package `Logging`, then any consumer must `import Logging` to see it. Multiply that across every seam type and a producer ends up importing many internal packages. `SharedProtocols` collapses that to one import.

Live writers import `SharedProtocols` for the protocol and the external framework for the concrete, never an intermediate package.

## Example

```swift
// Sources/SharedProtocols/Coordinators/AppCoordinator.swift
import SwiftUI
import Combine

@MainActor
public protocol AppCoordinator: AnyObject {
    func showWelcome()
    func showMainApp()
    func start()
}
```

```swift
// Sources/SharedProtocols/Coordinators/PreviewHelpers.swift
import SwiftUI

#if DEBUG
public final class Preview_AppCoordinator_Impl: AppCoordinator {
    public init() {}
    public func showWelcome() {}
    public func showMainApp() {}
    public func start() {}
}
#endif
```

```swift
// Sources/SharedProtocols/TileSummary.swift
import Foundation

public struct TileSummary: Identifiable {
    public var id: UUID
    public var title: String
    public init(id: UUID = .init(), title: String) {
        self.id = id
        self.title = title
    }
}
```

`Package.swift`:

```swift
let sharedProtocolsTarget = Target.target(
    name: "SharedProtocols",
    dependencies: []   // zero internal deps
)
```

Every feature target depends on `SharedProtocols` and nothing else internal:

```swift
let tileFeatureTarget = Target.target(
    name: "TileFeature",
    dependencies: ["SharedProtocols"]
)
```

## Anti-patterns

### Per-capability locator protocols

```swift
// Avoid: a protocol invented to satisfy a DI checklist
public protocol BinaryLocating: Sendable {
    func locateBinary() -> String?
}
```

The composition root can probe the filesystem itself in three lines. The producer does not need a locator abstraction.

### Protocol nested under a namespace anchor

```swift
// Avoid in SharedProtocols
extension SharedProtocols {
    public protocol Recording { /* ... */ }
}
```

Top-level (`public protocol Recording`) reduces noise at call sites and matches `import SharedProtocols` ergonomics.

### Inline protocol declared in a producer file

```swift
// Avoid: a cross-target seam declared in the producer that uses it
public protocol TileProviding: Sendable {
    func validate() async throws -> Bool
}
```

A composition root would have to import the producer to see the protocol. The dependency arrow is reversed.

## Stop rule

Before adding a new `import` to a producer Swift file:

1. Is it an external framework or SPM product? Fine.
2. Is it `SharedProtocols`? Fine.
3. Anything else internal? **STOP.** Either move the seam into `SharedProtocols`, or push the orchestration up to the composition root.

## CI guard

```bash
# SharedProtocols must have no internal-package imports.
# External imports (Foundation, SwiftUI, Combine, ...) are fine.
INTERNAL_TARGETS=$(swift package describe --type json | jq -r '.targets[].name')
for ln in $(grep -rn '^import ' Packages/Sources/SharedProtocols/); do
    mod=$(echo "$ln" | awk '{print $2}')
    if echo "$INTERNAL_TARGETS" | grep -qx "$mod"; then
        echo "FAIL: SharedProtocols imports internal target $mod ($ln)"
        exit 1
    fi
done
```

## Sequencing

If you migrate existing scattered protocols into `SharedProtocols`, do it as one coordinated arc, not a per-package vote:

1. Move every cross-target protocol and value type into `SharedProtocols`.
2. Update every internal target's deps: producers gain `["SharedProtocols"]` and drop intermediate packages; live writers gain `["SharedProtocols", <external framework>]`.
3. Update every old `import` to `import SharedProtocols`.
4. Delete the now-empty intermediate source directories and target declarations.
5. Build and test green; commit.

## Related rules

- [dependency-injection.md](dependency-injection.md): DI principles the seams serve
- [package-import-contract.md](package-import-contract.md): what each target may import
- [package-architecture.md](package-architecture.md): package layers and granularity
- [package-structure.md](package-structure.md): repository and manifest layout
