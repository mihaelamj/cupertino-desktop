# Systematic Debugging

Find and articulate the root cause of any bug, test failure, or unexpected behavior before proposing or applying a fix. Symptom fixes are forbidden until you can explain why the symptom occurs.

## Core rules

### Rule 1: Reproduce first, investigate second, fix third

Complete the phases in order.
- Get a deterministic reproduction (test, sample input, repro script) before reading code
- MUST identify the smallest change that flips the outcome before naming it the cause
- MUST NOT propose a fix until you can describe the cause in one sentence

### Rule 2: The four phases

```
1. REPRODUCE
   - capture exact failing command (swift test --filter X, app run with input Y)
   - confirm it fails consistently
   - if flaky, treat the flake as the primary bug

2. ISOLATE
   - bisect: which target, which file, which line
   - for tests: shrink to the smallest failing assertion
   - for crashes: get the full stack trace with line numbers

3. EXPLAIN
   - state the root cause in one sentence
   - identify the invariant that was violated or assumption that was wrong
   - if you cannot explain, you have not found the cause yet

4. FIX
   - the smallest change that addresses the cause, not the symptom
   - add or update a test that would have caught it
   - run the verification gate (see docs/rules/verification.md)
```

### Rule 3: Common Swift pitfalls to check first

Consider these before deeper investigation:

- **Force unwrap on optional**: search for `!` near the crash site; trace where the optional became nil
- **Concurrency**: was the failing code on the expected actor or thread? Check `@MainActor`, `Sendable` violations, structured concurrency hops
- **Dependency injection**: did a test forget `withDependencies`? Did a default `liveValue` leak into the test?
- **Strict concurrency**: Swift 6 errors often surface as "data race" warnings in Swift 5 mode. Check the migration mode of the affected target.
- **Generic type inference**: a fix that "looks right" but the compiler flags is often hiding an inference loop
- **Cache or stale build**: try `swift package clean && swift build` if behavior contradicts the visible source

### Rule 4: Banned behaviors during debugging

**MUST NOT**:
- Apply a fix to make the test pass without understanding why it was failing
- Wrap the failing call in `try?` or `if let` to silence the symptom
- Add `@MainActor` to "fix" a concurrency error without confirming the call site needed it
- Disable the failing test
- Skip the test with `.disabled` and move on
- Attempt multiple fixes in parallel hoping one sticks

If a fix does not hold, return to phase 2 (Isolate). Do not stack guesses.

### Rule 5: Reporting

State, in this order, when reporting on a debugging session:
1. The reproduction (command + expected vs actual)
2. The root cause (one sentence)
3. The fix (what changed and why it addresses the cause, not the symptom)
4. The verification (which test now passes that did not before)

## Anti-Patterns

- "I think it might be X, let me try" applied to multiple guesses in series
- Adding logging without a hypothesis to test
- Reading the whole file looking for "something off" instead of bisecting
- Calling a flake "transient" without finding the race
- Declaring a fix complete because the failing test now passes, without checking why the others still pass
