# Per-Package Import Contract

The rule for what each SPM target may `import`. Tiledown is a monorepo from day one with many targets in one package, and the engine (`TileKit`) and CLI (`tile-down`) are already two targets, so this contract applies now and governs every target added to the manifest.

This is the operational companion to [dependency-injection.md](dependency-injection.md) and [shared-protocols.md](shared-protocols.md). Read those first for the underlying principles (no singletons, constructor injection, protocol seams).

## The goal

Every target should be able to be lifted out of the monorepo and built on its own against only its declared external dependencies. To make that true, each target has a hard contract about what it may `import`. Anything outside that contract is a violation and must be fixed in the same change.

The shape is: single-responsibility targets with unidirectional dependencies. A target never reaches sideways into a peer's concrete implementation; it talks to a protocol seam, and the composition root supplies the concrete.

## The SPM target name is load-bearing

Before any restructure that touches a target (folder move, file rename, type rename, namespace change), treat the SPM target name as the highest-stability anchor. Preserve it unless the rename IS the goal of the change.

The target name is what every consumer writes as `import <TargetName>`. Changing it cascades through every file that imports it, every doc that names it, and every test target's `dependencies:` list. Treat it like the public API of the package.

Order of operations for a refactor:

1. Anchor on the target name. The import line stays the same.
2. Move and rename files inside the target freely. The compiler does not care.
3. Rename folders, including SPM `path:` overrides, freely. Consumers do not see this.
4. Rename public types behind a `public typealias OldName = NewName` so direct references still compile; migrate them later and drop the alias when uses hit zero.
5. Rename the target itself only as a dedicated change with explicit acceptance criteria (every consumer updated, every test green, every doc swept). Never as a side effect of a folder restructure.

Priority order: target name > public type > file name > folder layout.

## Stop rule (before adding any `import`)

Before adding an `import X` line to a producer target, ask:

1. Is `X` external (Foundation, a system framework, ArgumentParser, Testing, a vetted third-party dependency)? Allowed.
2. Is the target an `executableTarget` / composition root (for example the `tile-down` CLI)? Allowed; the composition root wires the universe.
3. Is `X` a foundation-tier target that is foundation-only by construction (shared constants, value types, read-only diagnostics)? Allowed.
4. Is `X` a protocol-seam package (foundation-only by contract, carrying only protocols and value types)? Allowed.
5. Otherwise: **STOP.** Surface the situation; do not proceed. Importing another producer's concrete target is forbidden. Route the dependency through a protocol seam; the composition root supplies the concrete via injection.

If you proceed past the stop rule, you have coupled two producers, which is exactly the coupling this rule exists to prevent. Every package should keep full autonomy, every dependency injectable, so any package can be pulled out of the monorepo at any time.

## The rules

1. **External primitives are always allowed.** `Foundation`, `os`, `OSLog`, `Combine`, system frameworks, `ArgumentParser`, `Testing`, `XCTest`, and vetted third-party SPM products are ambient and never count as a violation.
2. **A producer target may import its own protocol-seam companion.** That is the foundation-only protocol and value-type seam the producer publishes.
3. **A producer target may import other protocol-seam targets.** They are foundation-only by construction; importing one carries no behavioural coupling.
4. **A producer target may not import another producer (feature) target.** Cross-feature coupling goes through protocols defined in a seam package; the concrete is supplied at the composition root.
5. **A producer target may not depend on a concrete writer.** Consumers hold the protocol type from the seam package; the binary supplies the live implementation.
6. **Read-only foundation infrastructure can be imported widely** (embedded resources, read-only diagnostics). Treat it like Foundation.
7. **Composition roots can import anything.** The CLI and any other app/binary wire the live concretes and pass them down.
8. **No singletons reachable from producer code.** No `static let shared = X()`, no static config accessors. Pass the value as a parameter. The composition root constructs once and threads it down.
9. **A "this singleton is sanctioned" argument is not a get-out.** Even where a singleton would be technically acceptable, the project rule is strict dependency injection.

## What this rule does not say

- It does not ban a per-category static `os.Logger` constant; that is the Apple idiom (an `os.Logger` is a value-type wrapper meant to be held statically).
- It does not ban a `static let cache = Cache()` internal detail that is not reachable from consumers (for example a memoization cache inside a static loader). That is not a singleton in the service-locator sense.
- It does not ban a composition root constructing one instance and treating it as a local `let`. That is just a value, not a singleton.

## Per-project checked-in contract

Keep a `docs/package-import-contract-status.md` with one table row per target listing:

- **Target name**
- **Allowed imports** (the explicit list; anything else is a violation)
- **Current state** (matches / excess imports listed)

This file is the single source of truth a reviewer can grep against.

## CI enforcement

Two checks back the contract:

- A source-import audit: grep `^import` lines per target and fail if a consumer imports a forbidden producer.
- A portability check: copy a target plus its declared transitive deps into a temporary directory, generate a minimal `Package.swift`, and run `swift build`. Green means the target genuinely lifts standalone with only its declared deps. Sweep across every producer target in CI.

## When auditing the packages

1. List every target.
2. For each, run `grep -h '^import ' Sources/<Target>/**/*.swift | sort -u` to see actual imports.
3. Compare against the contract. Producer importing another producer is a violation. Producer importing a concrete writer is a violation. A singleton reachable inside a producer is a violation.
4. Open an issue or PR for each violation, smallest first.

## No closure typealiases at cross-target seams

Closure typealiases like:

```swift
public typealias TileLookup = @Sendable (String) async throws -> Tile?
```

are forbidden for cross-target seams. Use a named protocol instead:

```swift
public protocol TileLookupStrategy: Sendable {
    func lookup(id: String) async throws -> Tile?
}
```

Reasons:

1. **Named.** A protocol shows up by name in tooling, error messages, documentation, and test stubs. A closure typealias is just a tuple-to-tuple mapping.
2. **Discoverable.** "Find all conformers" works; "find all closure literals matching this signature" does not.
3. **Forces a real type at the conformer side.** A protocol conformer is a named struct or actor with explicit captured state, not an inline literal at the binding site.
4. **The Factory Method and Strategy patterns are defined in terms of types, not function values.** Keeping the named-type shape keeps the design legible.

This does not ban closures as method parameters or property values; `onProgress: (@Sendable (Progress) -> Void)?` is fine. It bans closure-typed named cross-target contracts.

## Reference

- Gamma, Helm, Johnson, Vlissides, *Design Patterns* (1994). Factory Method p. 107; Strategy p. 315; Singleton p. 127 (we do not use the third one).
- Mark Seemann, *Dependency Injection in .NET* (2011). Service Locator anti-pattern ch. 5; Composition Root ch. 4.

## Related rules

- [dependency-injection.md](dependency-injection.md): underlying DI principles
- [shared-protocols.md](shared-protocols.md): where the protocol seams live
- [package-architecture.md](package-architecture.md): package layers and granularity
- [package-structure.md](package-structure.md): repository and manifest layout
