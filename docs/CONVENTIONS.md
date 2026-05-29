# Tiledown Conventions

The coding conventions for Tiledown. They keep the codebase consistent,
testable, and portable. Read this before opening a PR. When in doubt, read the
surrounding files and match what is already there: consistency with existing code
outranks personal preference.

This page is the overview. The full per-area rules live in
[`docs/rules/`](rules/) (index at [`docs/rules/README.md`](rules/README.md)).

## Language

Swift for everything. The single exception is JavaScript, and only where it is
intrinsic to the output: client-side tiles (Mermaid, charts, forms, polls) emit
HTML and JS that run in the visitor's browser. JS is never used for build logic or
tooling.

## Engineering principles

1. **Optimal over fast.** Respect existing code and idioms. Clarify ambiguity
   before coding rather than assuming requirements. When a real trade-off exists,
   surface two or three options instead of guessing.
2. **Progressive architecture.** Start with the simplest thing that works. Add a
   protocol only when a second concrete consumer exists. Generalise only when a
   pattern has actually emerged. Do not pre-abstract.
3. **Make impossible states unrepresentable.** Use exhaustive enums with
   associated values. Never force-unwrap (`!`, `try!`) in shipping code. Errors
   carry both a human-readable reason and an actionable recovery path.
4. **Testable by design.** Inject every collaborator through the initialiser. Test
   behaviour through the public API, not implementation details.
5. **Profile, then optimise.** Value semantics by default. Pick the right data
   structure first. Optimise only with a profile in hand.

## Dependency injection

- **No singletons.** No `static let shared`, no process-wide config reached
  through static accessors. Every dependency appears at the `init` site so
  coupling is visible, testable, and removable.
- **Every external collaborator goes through `init`.** Not method parameters at
  the call site, not static fallbacks, not environment lookup. Pure free functions
  that compute from their arguments are fine.
- **Cross-module seams are protocols, not concrete imports.** A library module
  does not reach into another module's concrete types. The executable (the
  composition root) is the only place that wires concretes together.
- **No closure typealiases for named cross-module contracts.** Use a named
  protocol. Closures as ordinary method parameters (`onProgress:`) are fine.

## Namespacing and file layout

- **Every public type lives under an `enum`/`struct` namespace that mirrors its
  folder.** No public type at file scope. Reading `Module.Sub.Leaf` should tell you
  where the type lives and what it does.
- **Namespace anchors are caseless `enum`.** Use `struct` only when the type is
  also a value. Never `class` for a namespace. Shared mutable state is an `actor`
  or an injected value, never a `class`.
- **Drop redundant context.** Under `Availability`, the error is `Availability.Error`,
  not `AvailabilityError`.
- **Concrete types are declared via extensions** on the leaf namespace.
  Conformances may be separate extensions on the qualified path.
- **One non-private type per file.** Private helper types may co-locate when they
  exist only to support the main type.
- **File naming.** A file declaring `extension Foo.Bar { public struct X }` is
  named `Foo.Bar.X.swift` (dots, matching the qualified name). Anchor files
  contain only the namespace declaration, no implementation.

## Concurrency

- Swift 6 strict concurrency is on. Types crossing concurrency boundaries are
  `Sendable`; prove it, do not silence it with `@unchecked` unless you have a
  documented reason.
- Shared mutable state goes in an `actor`. UI-affine state is `@MainActor`.
- Use structured concurrency. No arbitrary `Task.sleep` to paper over ordering.

## Cross-platform

Tiledown builds and runs on macOS and Linux.

- Guard platform-divergent code and abstract platform-specific dependencies behind
  a protocol seam: one implementation per platform, wired by the composition root.
  Subprocess use is allowed.
- Prefer pure-Swift implementations over Foundation-only conveniences in the core.
- On the server side, prefer cross-platform libraries (for example AsyncHTTPClient
  over URLSession, swift-log over os.log).

## Testing

- Use the **Swift Testing** framework: `@Test`, `@Suite`, `#expect`. Not XCTest.
- One behaviour per test. Descriptive names. Deterministic data. No live network
  or filesystem dependence; inject test doubles.
- One test target per source target, named `<SourceTarget>Tests`.
- Use parameterised tests (`@Test(arguments:)`) for families of similar cases.

## Verification before "done"

Do not claim a change is done, fixed, or passing without fresh command output in
the same response. Match the command to the claim:

| Claim | Command |
|---|---|
| Build succeeds | `swift build` |
| Tests pass | `swift test` (cite the count, e.g. `42 / 42`) |
| Bug fixed | the test that reproduced it, now passing |

"Looks good" and "should pass" are not evidence.

## Commits, branches, PRs

See [CONTRIBUTING.md](../CONTRIBUTING.md). In short: Conventional Commits, one
focused change per PR, a `CHANGELOG.md` entry for any change touching shipping
source, and no AI attribution or em dashes in any committed text.
