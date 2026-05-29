# Package Architecture

How to decompose Tiledown into focused SPM targets within its single package. Tiledown is a monorepo from day one: one `Package.swift` under `Packages/`, many single-responsibility targets in it. The `TileKit` library and the `tile-down` executable are already two such targets, so the decomposition rules below apply now and guide every target that joins the manifest.

The pattern: single-responsibility SPM targets with explicit, unidirectional dependencies, all in one package. Each target has one cohesive job and declares exactly what it depends on. This buys isolated compilation, parallel builds, a clear dependency graph, and targets you can test (and lift out) in isolation.

## What this covers

Tiledown already has more than one target (the `TileKit` library and the `tile-down` CLI). Add a new target to the single package when one of these is true:

- A part of TileKit has become a clearly separable responsibility (a parser, a transport, a renderer) used in more than one place.
- Compilation is slow and a large stable chunk would benefit from being its own target.
- A second front-door appears (an app target, a server, a second CLI verb set).

## Core rules

### Rule 1: Single responsibility per package

Create packages with one clear purpose:

- One well-defined responsibility per package.
- Do not mix concerns (UI plus networking, models plus API client).
- The name communicates the purpose.
- Independently buildable and testable.

### Rule 2: Explicit dependency declaration

Declare dependencies explicitly in `Package.swift`:

- List every dependency in the manifest.
- No reliance on implicit or transitive dependencies.
- Minimize cross-package dependencies.
- Prefer unidirectional dependency flow.

### Rule 3: Package granularity

Prefer smaller, focused packages over larger ones:

- Single-file packages are fine when the unit is genuinely standalone (a color foundation, a single protocol, a single transport).
- Separate by role, not by topical bundling: foundation primitives, infrastructure, protocols, middleware, services, per-feature or per-verb operation packages, front-door binaries.
- Each cohesive responsibility (a feature, a CLI verb, a middleware, a transport, a service) gets its own package.

### Rule 4: Naming conventions

Use a consistent scheme. Patterns that travel across project shapes:

- **Shared foundation:** `Shared*` for cross-target value types, models, utilities, configuration (for example `SharedModels`, `SharedProtocols`).
- **Core infrastructure:** `Core*` or a descriptive single-purpose name for the foundation domain (protocols, parsers, transports).
- **Per-feature or per-verb operation packages:** one package per user-facing flow (in a UI app) or one per CLI verb (in a CLI). Name after the responsibility, not after a role suffix.
- **Service packages:** `*Service`, or a `Services` aggregator for cross-layer read/write services consumed by multiple front-doors.
- **Aggregators:** umbrella packages only when the umbrella adds real value (a preview host, an all-features aggregator for app composition). Do not add one by default.

For Tiledown specifically, keep the `TileKit` library name as the public anchor and grow new packages around it (for example `TileCore`, `TileParser`) rather than renaming it.

### Rule 5: Layer architecture (unidirectional)

Organize packages into layers with dependency flow strictly bottom to top. The exact number of layers varies per project; the constants are:

- **Foundation** (bottom): shared value types, models, primitive utilities, logging.
- **Infrastructure:** protocols, persistence, networking, file I/O, parsers, transports.
- **Domain:** services, business logic, per-feature or per-verb operation packages.
- **Presentation** (UI projects only): component packages, design-system packages, screens.
- **Front-door** (top): binary targets, apps, CLIs, preview hosts, test harnesses.

Every dependency edge points upward. No back-edges. The active layer instantiation lives in the project's own `Package.swift`.

## When to create a new package

### Decision tree

```
Need to add new code?
├─ Is it a reusable domain model or value type?
│   └─ YES → add to the shared foundation package (e.g. SharedModels)
│
├─ Is it a cross-target protocol seam?
│   └─ YES → add to SharedProtocols (see shared-protocols.md)
│
├─ Is it a complete user-facing feature or a distinct CLI verb?
│   └─ YES → create a new feature / verb package
│
├─ Is it infrastructure (transport, parser, persistence, middleware)?
│   └─ YES → create or extend the matching infrastructure package
│
└─ Still unsure?
    └─ Ask: "Could this be reused or tested in isolation?"
        ├─ YES → create a new package
        └─ NO  → add to the most specific existing package
```

### Create a new package when

1. **It is a complete feature or distinct verb** (a self-contained user-facing flow, or one CLI command's logic).
2. **It is reusable infrastructure** that can be tested in isolation and used by more than one consumer (a caching middleware, a transport).
3. **It wraps a third-party integration**, isolating that external dependency behind a seam.
4. **It is platform-specific** code that is cleaner separated (iOS-only vs macOS-only).
5. **It is a build-optimization win**: large, stable, or expensive-to-compile code (for example generated code) that rarely changes.

### Do NOT create a new package when

1. **It is single use**, only used by one feature and tightly coupled to it. Add it to that feature's package.
2. **It is a trivial helper** of one or two functions with no external dependencies. Add it to an existing utility package.
3. **It is temporary** (a spike or proof of concept). Keep it in the feature until it proves stable.

## Decision checklist

Before creating a new package:

- [ ] One clear responsibility
- [ ] Name follows the conventions above
- [ ] Dependencies are minimal and explicit
- [ ] No circular dependency introduced
- [ ] Can be built and tested in isolation
- [ ] Fits a single architectural layer
- [ ] Test target created alongside the source target
- [ ] Product registered in the `Package.swift` products array
- [ ] Dependencies only flow upward

Before adding to an existing package:

- [ ] The new code shares a responsibility with what is there
- [ ] No better-suited package exists
- [ ] You are not creating a "god package" with mixed concerns
- [ ] You are not introducing unwanted dependencies onto the package's consumers

Before modifying `Package.swift`:

- [ ] Used a closure-with-local-variables pattern for the `deps`, `allProducts`, and `targets` arrays rather than one giant inline array
- [ ] Grouped dependencies by purpose, products by platform, targets by layer, with comment headers
- [ ] Separated platform-specific code with `#if os(iOS) || os(macOS)` in the manifest
- [ ] Did NOT use `#if canImport(UIKit)` in `Package.swift` (the manifest evaluates it lazily and it breaks Linux builds; `#if os()` is parse-time and safe). In regular Swift source files, `#if canImport(UIKit)` / `#if canImport(AppKit)` is the correct idiom.
- [ ] Each target/product/dependency has a descriptive variable name
- [ ] Trailing commas in all arrays
- [ ] `.when(platforms:)` applied for platform-specific dependencies within targets

If you add a font or resource package:

- [ ] Used `.process()` for resources, never `.copy()`
- [ ] Accessed resources via `Bundle.module`, never `Bundle.main`
- [ ] Used `#if canImport(UIKit)` / `#if canImport(AppKit)` for platform imports
- [ ] The package has zero dependencies (resources are a foundation-layer concern)

## Example layout (illustrative, not normative)

As Tiledown grows targets within its single package, the layout might look like this. Your actual target list will differ.

```
Packages/Sources/
├── Foundation Layer (0 internal dependencies)
│   ├── TileCore          # core value types, no dependencies
│   └── SharedProtocols   # cross-target protocol seams
│
├── Infrastructure Layer
│   ├── TileParser        # depends: TileCore
│   └── TileTransport     # depends: SharedProtocols
│
├── Domain Layer
│   └── TileKit           # the main library; depends: TileCore, TileParser
│
└── Front-door (not under Sources/)
    └── tile-down         # the CLI executable; wires the concretes
```

## Related rules

- [package-structure.md](package-structure.md): repository layout and the `Package.swift` manifest shape
- [package-import-contract.md](package-import-contract.md): what each target may import
- [shared-protocols.md](shared-protocols.md): the cross-target protocol-seam package
- [dependency-injection.md](dependency-injection.md): the DI principles these layers serve
