# Swift 6 Strict Concurrency

Concurrency posture for TileKit and Tiledown: immutability first, sparse actors, escape hatches always justified, grounded in the Swift Evolution proposals.

Triggers: `async`, `await`, `actor`, `Sendable`, `@MainActor`, `Task`, `nonisolated`, `sending`, `AsyncSequence`, `AsyncStream`, `withTaskGroup`, `@unchecked`, isolation, data race, cross-actor.

**Canonical source: Swift Evolution proposals.** Each rule below points at the proposal(s) that introduced and justify the feature. When in doubt about a rule, re-read the proposal's Motivation section. That is the load-bearing context, not the rule's summary here.

## Overall posture

Strict concurrency is achievable without region-based isolation, complex task hierarchies, or pervasive locking. The discipline is:

1. **Immutability first.** Default to value-typed structs that get implicit `Sendable`. Reach for `actor` only when global mutable state genuinely exists.
2. **Sparse actor use.** Reserve `actor` for cross-task shared state (transports, file watchers, registries). Don't actor-ify every stateful type.
3. **`@MainActor` is rare in CLI/library code.** Wrap UI-touching types only. Don't smear `@MainActor` across non-UI code to "make it compile."
4. **`@unchecked Sendable` and `nonisolated(unsafe)` are escape hatches.** Every use carries a one-line comment justifying why it is safe.

## Sendable

**Rule.** Implicit > explicit > `@unchecked`.

- Value types whose stored properties are all `Sendable` are **implicitly** `Sendable`. Don't restate.
- Add explicit `: Sendable` on **public** value types so the API surface declares intent:
  ```swift
  public struct Progress: Sendable {
      public let current: Int
      public let total: Int
  }
  ```
- Error enums: always explicit.
- `@unchecked Sendable` only for wrappers around known-safe non-value types, with a one-line justification:
  ```swift
  // URLSession is thread-safe; this wrapper is stateless.
  struct ContentFetcher: @unchecked Sendable { ... }
  ```
- Never combine `@unchecked Sendable` with hand-rolled `NSLock` / `DispatchQueue` in new code. If you need locks, use `actor`.

**Why (SE-0302, Swift 5.5).** `Sendable` was introduced because passing arbitrary references across isolation boundaries makes data-race safety impossible to verify locally. The protocol turns *"is this safe to send across a concurrency domain?"* into a property the compiler can check by induction on stored properties. Implicit conformance for value types is the design intent: most structs should be `Sendable` without ceremony, because most value types compose `Sendable` parts. Explicit annotation on public types is for API clarity, not for the compiler.

**Why (SE-0418, Swift 6.0): inferred `Sendable` for methods and key path literals.** Function values and key paths needed parallel inference. Before SE-0418, you had to mark every closure parameter `@Sendable` by hand even when the closure captured only `Sendable` state. Rule of thumb after this proposal: if every captured / referenced type is `Sendable`, the function is `Sendable`. Bookkeeping cost goes to zero.

**Why (SE-0463, Swift 6.2): Obj-C completion handlers as `@Sendable`.** Objective-C completion handlers were imported without `@Sendable`, so calling Swift code from an ObjC framework had a hole in its concurrency proof. Swift 6.2 closes the hole. Concrete impact: bridging code that was previously `@unchecked Sendable` to silence the warning can now drop the `@unchecked`.

**Why (SE-0331, Swift 5.6): unsafe pointers are NOT Sendable.** `Unsafe(Mutable)(Buffer)Pointer` originally conformed to `Sendable` unconditionally. SE-0331 removed that conformance because the inference rules made arbitrary types accidentally `Sendable` when they contained an unsafe pointer to non-`Sendable` data. Lesson: `Sendable`'s safety model only holds if every conformance is honest. Don't add `@unchecked Sendable` to wave away a real race.

## Actors

**Rule.** `actor` is for **cross-task shared mutable state**: transports, file watchers, registries with concurrent readers/writers. Not for everyday data.

- Don't actor-ify data pipelines. A struct that gets copied is a better default than an actor that gets awaited.
- Inside an `actor`, methods are isolated by default. Mark synchronous reads of immutable storage or global resources as `nonisolated`:
  ```swift
  actor Screen {
      let columns: Int                        // immutable, captured at init
      nonisolated var size: (Int, Int) {      // POSIX ioctl, no actor state
          var ws = winsize()
          _ = ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws)
          return (Int(ws.ws_col), Int(ws.ws_row))
      }
  }
  ```

**Why (SE-0306, Swift 5.5).** Actors exist because mutable state shared across concurrent contexts is the canonical source of data races. Before actors, the Swift solution was *"don't share mutable state"* (value semantics) or *"use a lock"* (manual). Neither composes with `async/await`. An `actor` provides a structured, compiler-enforced way to express "this state is mutable but accessed serially through a single isolation domain." The serialisation is the safety guarantee; reentrancy (multiple suspended tasks on one actor) is the cost.

The reentrancy point matters for design: an `actor`'s state can change *between* `await` points inside the actor. Don't write `actor` methods that assume invariants survive a suspension. Re-read after every `await`.

**Why (SE-0327, Swift 5.10): actor initialisation.** Originally, actor `init` rules were strict: every stored property had to be initialised before any method call. SE-0327 relaxed this so an actor's `init` can be synchronous and call its own (nonisolated) methods. Practical impact: actor init is *not* isolated until the first hop, so you can do synchronous setup work in `init` without `await`.

## `@MainActor`

**Rule.** Type-level on UI-owning types, method-level in tests, rarely on protocols.

- **Type-level `@MainActor`** for types that own UI/AppKit/UIKit objects:
  ```swift
  @MainActor public final class WindowCoordinator {
      private let window: NSWindow
      ...
  }
  ```
- **Method-level `@MainActor`** in test code where you want the test on main:
  ```swift
  @MainActor func testTileRendering() async throws { ... }
  ```
- **Protocol-level `@MainActor`** only when every conforming implementation truly needs main-thread isolation. Prefer leaving protocols isolation-agnostic.
- CLI / library code rarely needs `@MainActor`. If you reach for it in a non-UI target, ask whether you actually want `actor`.

**Why (SE-0316, Swift 5.5): global actors.** Sometimes the right isolation is not per-instance (an `actor`) but per-application (the main thread). `@MainActor` is a global actor that says *"any type or method bearing this annotation runs on the main thread, full stop."* The motivating use case is UI frameworks: AppKit / UIKit are inherently main-thread, and `@MainActor` lifts that constraint into the type system so the compiler enforces it instead of runtime queue assertions.

**Why (SE-0434, Swift 6.0): usability of global-actor-isolated types.** Before SE-0434, `@MainActor` types had awkward interactions: stored properties could not be read from non-isolated contexts even when they were `let` and `Sendable`, you could not conform `@MainActor` types to non-isolated protocols, and so on. SE-0434 closes those gaps. Practical impact: `@MainActor` is now significantly more ergonomic in Swift 6.0+.

**Why (SE-0470, Swift 6.2): global-actor isolated conformances.** A type can now have a conformance that is itself isolated to a global actor. Lets you say "this type conforms to `Codable`, but its `Codable` requirements run on `@MainActor`." Niche, but unblocks cases where the underlying type stays UI-bound while still participating in serialization or other protocol contracts.

## `nonisolated` and `nonisolated(unsafe)`

**Rule.** `nonisolated` for methods that don't touch isolated state. `nonisolated(unsafe)` is the escape hatch for fire-and-forget globals or test escape hatches, always commented.

- **`nonisolated` (safe)** on methods/properties of an isolated type that don't read isolated state:
  ```swift
  // POSIX file descriptors are global; no actor state read.
  nonisolated func writeRaw(_ bytes: [UInt8]) {
      _ = write(STDOUT_FILENO, bytes, bytes.count)
  }
  ```
- **`nonisolated(unsafe)`** reserved for:
  - Fire-and-forget logging state (read-mostly, last-write-wins is acceptable)
  - Test-only escape hatches (stdin overrides, DI test seams)

  One-line comment justifying:
  ```swift
  // Logging is fire-and-forget; last-write-wins is acceptable for these flags.
  nonisolated(unsafe) static var minimumLevel: Logging.Level = .info
  ```
- Never `nonisolated(unsafe)` to silence a warning on shared mutable state that needs synchronisation. Fix the design.

**Why (SE-0412, Swift 6.0): strict concurrency for global variables.** Before SE-0412, global `var`s were a backdoor: they bypassed the actor model entirely and were a frequent source of data races in Swift 5 code. SE-0412 closes the backdoor by requiring global mutable state to be either (a) isolated to a global actor, (b) immutable (`let`), or (c) explicitly marked `nonisolated(unsafe)` with the developer accepting the responsibility.

The `(unsafe)` marker is **intentionally ugly**. It is there so reviewers can grep for it and ask "is this race actually acceptable?" The proposal's stance: most globals should be `let`, some should be `@MainActor`-isolated, and `nonisolated(unsafe)` should be rare and justified.

## Region-based isolation (`sending`)

**Rule.** Almost never needed if you stay immutable-by-default. If you reach for `sending`, first ask whether the value can be made `Sendable` by construction (immutable struct of `Sendable` parts).

**Why (SE-0414, Swift 6.0): region-based isolation.** Strict `Sendable` checking forbids passing non-`Sendable` values across isolation boundaries. But many real programs *create* a non-`Sendable` value in one isolation domain, then *hand it off* to another and stop using it themselves. That is a race-free pattern, but pre-0414, the compiler could not see it.

Region-based isolation lets the compiler track "this value's region of access" and prove the hand-off is safe even though the type is not `Sendable`. The proposal's example: an actor builds up a non-`Sendable` mutable buffer, then transfers it to another actor. After the transfer, the original actor cannot reach the buffer; the receiving actor has exclusive access.

**Why (SE-0430, Swift 6.0): `sending` parameter and result.** The `sending` annotation is how you express the transfer in an API signature: *"This parameter is sent to me, the caller cannot use it after this call. This result is sent to you, I cannot use it after returning."* The proposal preserves the semantics from SE-0414 but moves them from inferred regions to explicit annotations at API boundaries.

Practical takeaway: most codebases do not need `sending`. It is for libraries that build non-`Sendable` graphs (parser ASTs, large mutable buffers) and need to hand them across actor boundaries. If your data is immutable, you do not need it.

## Task patterns

**Rule.** `Task { ... }` for cleanup and isolation hops. `Task.detached { @Sendable ... }` for bridging synchronous APIs. `withTaskGroup` for bounded parallelism.

- **`Task { ... }`** inherits the caller's actor isolation:
  ```swift
  defer { Task { await transport.disconnect() } }     // cleanup
  Task { @MainActor in coordinator.onClose() }         // hop to MainActor
  ```
- **`Task.detached { @Sendable ... }`** starts a new, unisolated task. Use only for bridging synchronous APIs (FileManager enumerators, blocking IO, legacy callbacks):
  ```swift
  Task.detached(priority: .userInitiated) { @Sendable () -> [URL] in
      // sync-only FileManager work
  }
  ```
- **`withTaskGroup { ... }`** for bounded parallelism. Always bound the group; never spawn unbounded.
- **Cancellation:** rely on `await` points to check cancellation implicitly. Explicit `try Task.checkCancellation()` at the top of long synchronous loops; `Task.isCancelled` for graceful bail-out without throwing.

**Why, structured concurrency.** `Task { ... }` is the structured form: the task inherits priority and isolation from the spawning context, and its lifetime is bound to the enclosing scope. `Task.detached` is the unstructured form: a new, independent task with no inheritance. The default should be structured; reach for `Task.detached` only when you specifically need to break the inheritance chain (for example detaching from `@MainActor` to do sync work, or detaching from a parent that might be cancelled when the child should not be).

**Why cancellation is cooperative.** Swift's cancellation model is intentionally **cooperative**: setting `Task.isCancelled` does not halt execution. The task must check the flag and exit. This is by design; abrupt cancellation makes resource cleanup impossible. Practical pattern: every `await` is a cancellation point (the framework checks for you); for long synchronous loops, add explicit `try Task.checkCancellation()` at iteration boundaries.

## `AsyncSequence` and `AsyncStream`

**Rule.** `AsyncStream` is the canonical channel for "events arrive over time." For single-consumer progress callbacks, prefer a `@Sendable (Progress) -> Void` closure.

Typical shape:
```swift
actor Channel {
    let messages: AsyncStream<Message>
    private var continuation: AsyncStream<Message>.Continuation!

    init() {
        (messages, continuation) = AsyncStream<Message>.makeStream()
    }

    func send(_ m: Message) { continuation.yield(m) }
}
```

Back-pressure: pick a buffering policy deliberately (`.unbounded`, `.bufferingNewest(n)`, `.bufferingOldest(n)`). Default is unbounded, fine for low-rate event streams, dangerous for high-rate producers.

**Why.** `AsyncSequence` generalises the iterator pattern over time. `AsyncStream` is the concrete bridge from "push" producers (callback APIs, delegate methods, system event sources) to "pull" consumers (`for await`). The split between protocol and concrete type lets stdlib types (network responses, file reads) and your own channels share the same `for await` syntax.

When to **not** use `AsyncStream`: single-callback progress reporting. A `@Sendable (Progress) -> Void` closure passed at the call site is simpler, has no buffering question, and is easier to test.

## Cross-actor calls

**Rule.** Pass `Sendable` values, await across the boundary. Explicit `await MainActor.run { ... }` for event boundaries only.

- Default: the compiler handles the isolation hop when you `await` an isolated method.
- Don't pass non-`Sendable` references across isolation domains. If you find yourself wanting to, either (a) make the type `Sendable`, (b) marshal data into a `Sendable` value, or (c) use `sending` (rare).
- `await MainActor.run { ... }` is for event boundaries (UI callback, terminal redraw), not as a workaround for "this code happens to need to be on main."

**Why.** The actor model only delivers data-race safety if values crossing boundaries are `Sendable`. The compiler enforces this; you cannot "just pass it", you have to either prove safety (via `Sendable`) or accept responsibility (via `@unchecked`/`sending`).

## Test concurrency

**Rule.** Native `async throws` test methods. Actor-isolated state read via `await actor.value`. No `XCTestExpectation` in new code.

- Async tests:
  ```swift
  @Test func renderer_returns_expected_output() async throws {
      let index = await TileIndex.build(...)
      let results = await index.search("foo")
      #expect(results.count == 3)
  }
  ```
- Actor under test: `await actorInstance.value` to read across the boundary. Use a dedicated `actor SendableCounter` test double when accumulating state from outside.
- `XCTestExpectation` / `fulfillment(of:)` only when interoperating with legacy callback APIs. Native async/await is simpler.

## Anti-patterns

Avoid in new Swift 6 code:

- `DispatchQueue.main.async { ... }` → use `Task { @MainActor in ... }` or `await MainActor.run { ... }`.
- `NSLock` / `pthread_mutex` + `@unchecked Sendable` → use `actor`.
- `withCheckedContinuation` / `withUnsafeContinuation` → only when wrapping legacy callback APIs.
- `@MainActor` smeared across non-UI types to silence warnings → fix the design.
- `nonisolated(unsafe)` to bypass a warning without thinking about the race → fix the design.
- `Task.detached` as the default → use `Task { ... }` unless you specifically need unisolated execution.

## Vision

The current direction of Swift concurrency is captured in *"Improving the approachability of data-race safety"* (vision document, referenced by SE-0463, SE-0466, SE-0470). The vision: data-race safety should be the default, but the cost of opting in (annotations, refactors) should keep dropping. Each Swift 6.x release closes another gap that previously forced an `@unchecked` or a `@MainActor` smear.

When designing a new type, ask: *"will this need annotations to be `Sendable`/isolated, or can I make the design itself simple enough that the compiler infers everything?"* The vision answer is the second.

## Cross-references

- `dependency-injection.md` rule 4: no closure typealiases at cross-module seams. Closures as method parameters / property values are still fine; only the named cross-module typealiases are banned.
- `../decisions/point-free-dependencies.md`: open decision on the within-module Point-Free Dependencies pattern (closure-based, `@Sendable` closures). Undecided, not a rule.

## Reading the proposals

The rules above are summaries. The proposals' Motivation sections carry the full reasoning. When designing something non-trivial, read the relevant proposal end-to-end:

- SE-0306: actors
- SE-0302: Sendable
- SE-0414: region-based isolation
- SE-0412: strict concurrency for globals

The Swift Programming Language book's Concurrency chapter is the second canonical source. Apple also publishes a data-race-safety migration guide.

When a rule above and a proposal disagree, the proposal wins. Update this file.
