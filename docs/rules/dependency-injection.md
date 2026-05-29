# Dependency Injection Rules

Canonical dependency-injection principles for TileKit and the wider Tiledown codebase: no singletons, constructor injection, protocol seams.

These are standing rules for every change and every PR. They are grounded in *Design Patterns* (Gamma, Helm, Johnson, Vlissides, 1994) and Mark Seemann's *Dependency Injection in .NET* (2011).

## 1. No Singletons. Ever.

- **No `static let shared = X()`**. Not on a `final class`. Not when the class is immutable. Not when *Design Patterns* (1994, p. 127) explicitly sanctions the pattern.
- **No static accessors** that reach into a process-wide config holder. That is a Service Locator (Seemann 2011, ch. 5) and it counts.
- **No "but this case is sanctioned" soft framing.** When tempted to document a Singleton as "legitimate per p. 127," stop. Do the injection.
- **Apple's `os.Logger` per-category statics** are allowed; they are Apple's idiom, not ours.
- **Internal-detail caches** (`private static let cache = Cache()` inside a static enum loader) are not the kind of Singleton being banned. They are memoization, not Service Locator, and are not reachable from consumers as a dependency.

Why: every dependency must appear in the call graph at the type's `init` site, not be conjured from process-wide state at runtime. That makes coupling visible, testable, and removable.

## 2. Every external collaborator goes through `init`. No exceptions.

- Paths, factories, strategies, loggers, indexes, anything not owned by the type itself goes through the **constructor**.
- Not through method parameters at the callsite. Not through `static var` fallbacks. Not through environment lookup.
- **Pure free functions** that compute a value from arguments are fine (no state).
- **Stateful types with collaborators** take them via `init`.

Example for TileKit:

```swift
public struct TileRenderer {
    private let loader: TileLoading
    private let logger: Logging

    public init(loader: TileLoading, logger: Logging) {
        self.loader = loader
        self.logger = logger
    }
}
```

## 3. Cross-module coupling via protocols, not concrete imports.

- Code that crosses a module boundary depends on a **named protocol**, not on a concrete type imported from another module.
- The composition root (the executable target / app entry point) is the only place that holds concretes from multiple modules and wires them together.

If and when Tiledown grows into multiple SPM packages:

- A feature/producer package may **not** `import` another feature/producer package.
- Cross-package seams are **named protocols**, either declared in a small foundation-only `*Models` package or inlined per package.
- The composition root remains the only place that imports concretes from several packages.

## 4. No closure typealiases at cross-module seams.

Forbidden at cross-module seams:

```swift
public typealias TileLookup = @Sendable (String) async throws -> TileType?
```

Required:

```swift
public protocol TileLookupStrategy: Sendable {
    func lookup(uri: String) async throws -> TileType?
}
```

Reasons: a named protocol is discoverable (you can find all conformers), it forces a real type at the conformer site, and it matches the Factory Method / Strategy phrasing from *Design Patterns*.

- This does **not** ban closures as method parameters or property values. `onProgress: (@Sendable (Progress) -> Void)?` is fine.
- It **does** ban closure-typed *named* cross-module contracts.

## 5. Every module lifts out cleanly.

If and when Tiledown is split into multiple packages, each package should lift out of the repo without modification:

- If a package needs a dependency to function, that dependency is **named in its public API**.
- Hidden dependencies (ambient singletons, reach-into-shared-state, undeclared transitive imports) are violations even if they currently build.
- A mechanical lift-out check copies the package plus its declared transitive dependencies to a temp directory, generates a minimal `Package.swift`, and runs `swift build`. Green means it lifts out.

## 6. Composition root: binary name stays clean.

If Tiledown ships multiple binaries, the **executable target name** stays normal (no `Impl` suffix). The binary's external identity (filename on disk, `which` output) stays clean.

Use an `*Impl` namespace for the source files **inside** that target where each module is concretely glued together:

```swift
// Sources/CLI/CLIImpl.swift
public enum CLIImpl {}                       // namespace anchor

// Sources/CLI/CLIImpl.LiveTileLoaderFactory.swift
extension CLIImpl {
    struct LiveTileLoaderFactory: TileLoaderFactory { ... }
}
```

The `*Impl` namespace says "this file is where we wire concretes." Composition roots can `import` anything; they wire the universe. Library/producer code cannot import beyond its explicit allowed list.

## 7. Keep the import contract explicit.

If Tiledown grows into multiple packages, keep a checked-in `docs/package-import-contract.md`: one row per target listing target name, allowed imports, and current state. Anything outside the allowed column is a **violation** and must be fixed in the same change. Back it with a CI script that greps `^import` per target and fails on disallowed imports.

## 8. Foundation-only is the end state for producer packages.

The end goal for a multi-package split: producer packages import **only external primitives** (Foundation, system frameworks, vetted third-party SSG dependencies). Zero internal package imports. Each producer declares its own protocols inline. The composition root grows to bridge between per-package protocols.

Until then, a producer package may import:

- Foundation primitives and system frameworks
- Its own `*Models` companion and other foundation-only `*Models` protocol-seam targets
- A shared value-type layer, if one exists

Sequence the work: settle the singleton and static-state removal first, then pursue foundation-only producers as a separate effort. Do not fold the two together.

## 9. No relitigating a settled principle. Just do it.

- When the strict-DI / strict-portability path is chosen, **stop offering alternatives** and execute. Surface only **ordering** / **sequencing** questions, not principle-relitigation.
- Do not ask permission to fix obvious blockers (build failures, fatal crashes, CI breakers). Fix them. Reserve "want me to?" for genuinely debatable scope/timing calls.

## 10. Verify before claiming done.

- Use the project's canonical build command (`swift build`).
- Run the full test suite and cite the count: `142 / 142 pass`. "Tests pass" without a number is not evidence.
- If incremental build is acting strange (stale module errors, link errors against old signatures), clean the build and rebuild.

## 11. Keep the roadmap current.

Update the project roadmap (document or tracker issue) on every phase, release, or scope change. "Closed" means **shipped**, not "PR merged."

## 12. Documentation mirrors the user-facing surface in the same change.

When a CLI command, option, or other user-facing surface changes, update the documentation in the same change. Also update the CHANGELOG. Hand-curated, not auto-generated.

---

## Reference

- Gamma, Helm, Johnson, Vlissides, *Design Patterns* (1994). Factory Method p. 107; Strategy p. 315; Singleton p. 127 (we do not use the third one).
- Mark Seemann, *Dependency Injection in .NET* (2011). Service Locator anti-pattern ch. 5; Composition Root ch. 4.

## Stop rule (paste at the top of any session that touches imports)

Before adding `import X` to a producer module:

1. Is `X` external (Foundation, system framework, a vetted third-party dependency)? Allowed.
2. Is the target an executable target / composition root? Allowed.
3. Otherwise: **STOP.** Surface the situation. The target state is foundation-only.
