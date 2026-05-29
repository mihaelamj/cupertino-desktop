# Engineering principles

Judgment rules for every change to Tiledown code. Rules a machine can check live
in tooling (pointed to below); this file holds the judgment no tool can make.

## Primary directive

Choose the optimal path, not the fastest. Respecting existing code and idioms
outranks speed.

## Principles

1. **Progressive architecture.** Simplest thing that works first. Add a protocol
   only at the second concrete consumer; generalise only when a pattern has
   emerged. Do not pre-abstract.

   ```swift
   // 1. Direct
   func render() { ... }

   // 2. Protocol once a second implementation appears
   protocol Renderable { func render() -> String }

   // 3. Generic once a pattern emerges across types
   protocol Registry<Element> { ... }
   ```

2. **Make impossible states unrepresentable.** Model with exhaustive enums and
   associated values so invalid combinations cannot be constructed.

3. **Errors carry a reason and a recovery path.**

   ```swift
   enum TileError: LocalizedError {
       case unknownType(reason: String, recovery: String)

       var errorDescription: String? { /* reason */ }
       var recoverySuggestion: String? { /* recovery */ }
   }
   ```

4. **Testable by design.** Inject every collaborator through the initialiser; test
   behaviour, not implementation; wrap concrete framework types behind a protocol
   so a fake can substitute. See [dependency-injection.md](dependency-injection.md).

5. **Profile, then optimise.** Value semantics by default; the right data structure
   first; optimise only with a profile in hand.

## Respect existing idioms

Read the surrounding files first and match them. Idiom consistency outranks
personal preference. Do not introduce a new naming convention, structural choice,
or dependency-injection style that diverges from what is already in the codebase.

## Quality gates (judgment)

Before a change is done:

- Every error path has a recovery path or a documented terminal failure.
- Edge cases handled: `nil`, empty collection, invalid input, cancelled task.
- Every new public API has a documentation comment.
- Apple-platform APIs (in Apple-only code) verified against the authoritative
  reference: confirm the API exists with the claimed signature and follows current
  conventions.

Mechanical gates (no force-unwrap, no em dashes, no tool attribution, formatting,
build, tests) are enforced by tooling and CI, not by this file. See
[verification.md](verification.md), `.swiftlint.yml`, and `.swiftformat`.
