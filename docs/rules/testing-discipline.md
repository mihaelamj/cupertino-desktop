# Testing Discipline

When a change touches code, that change is not complete until tests have run. This rule defines when to run existing tests, when to write new ones, and what to report.

When the change touches code, the change is not complete until tests have run. If tests exist for the area being changed, run them. If no tests exist for the area being changed and the change is non-trivial, write them. Type-checks and successful builds are not tests.

This rule applies to any code change: new feature, bug fix, refactor, dependency bump, configuration change that affects behaviour. It does not apply to pure prose edits, documentation-only commits, or single-file readme touches.

## Core rule

### Rule 1: If a test suite exists, run it.

Before declaring the change done, run the project's test command:

- Swift Package: `swift test`
- Swift app target: project test scheme via `xcodebuild test`
- Python: `pytest`, `python -m unittest`, or the project's chosen runner
- JavaScript / TypeScript: `npm test`, `pnpm test`, `yarn test`, or the project's chosen runner
- Shell scripts: `bats`, `shellspec`, or the project's chosen runner
- Anything else: the command in the project's `README.md`, `Makefile`, `package.json` scripts block, or `pyproject.toml` `[tool.*.scripts]`.

The required output is the actual runner producing pass/fail counts, not a successful compile. `swift build` is not a test run. `tsc --noEmit` is not a test run. The test runner must execute and report.

Failures block the commit. Investigate and fix before shipping. Skipping with `.skip` / `xfail` / `@Disabled` is allowed only when the disabled test is genuinely unrelated to the current change and a follow-up issue is filed.

### Rule 2: If no test suite exists for the touched area, write one.

If the change adds a function, a class, a route, a CLI verb, a SQL view, a database migration, or any other addressable unit of behaviour, that unit gets at least one test. The test must:

- Exercise the unit by calling the public entry point (not by re-implementing it inside the test).
- Use real fixtures or a real local resource where the project supports one (real SQLite file, real temp directory, real fixture markdown). Mocks only when the dependency is a network call, an external service, or something the test infrastructure cannot reach.
- Fail when the implementation is wrong. Author a deliberate-bug version of the unit and confirm the test catches it. A test that passes against a broken implementation is not a test.
- Live in the project's existing test target / directory. Do not create a new top-level test scaffold beside a working one.

Trivial changes are exempt: a single-character typo fix, a comment, a doc string. Use judgement, but the bar is low: if there is *any* behaviour change, a test exists or gets written.

### Rule 3: Match the project's testing style.

A Swift project using Swift Testing (`@Test`, `@Suite`, `#expect`) does not get XCTest stubs added to it. A Python project using `pytest` does not get a `unittest.TestCase` class added. Read one or two existing tests, mirror their structure (fixtures, naming, parameterisation), and write the new test in the same idiom. Inconsistency in test style is itself a defect.

### Rule 4: Real tests beat smoke tests.

A "smoke test" that asserts only that the unit returns without throwing is the minimum acceptable form, not the target. Where the project has fixture-driven tests, the new test loads or constructs realistic input and checks realistic output. Prefer fixture-driven tests over smoke-only tests, and convert smoke-only tests into fixture-driven ones when you touch them.

A test that does not distinguish a correct implementation from a wrong one is no test. If a test can be satisfied by `return nil` or `return 0` or `return true`, strengthen it until it cannot.

### Rule 5: State the result in the response.

When reporting that a change is done, name the test command run and the result counts. "Ran `swift test`: 47 tests, 0 failures" is the deliverable, not "I made the change." If someone is going to verify the work, the test result is the verification, so it must be cited.

If tests were not run because none exist and the change was too small to justify writing one, say so explicitly. Do not let "I changed X" stand alone as a completion claim when there was a test command available.

## Exceptions

The rule does not require tests for:

- Documentation-only changes (`docs/`, `README.md`, code comments).
- Renames where the compiler proves equivalence (Swift `swift build` passes, TypeScript `tsc` passes, Python `mypy` passes).
- Configuration changes that have no behavioural effect (formatter config, editor settings).
- Generated files (lockfiles, build output, vendored dependencies).

When in doubt, write the test. The cost of writing a test you did not strictly need is small. The cost of shipping a regression to a system without a test that would have caught it is large.

## Mechanical enforcement

Where the project supports it, add the test run to:

- A pre-push hook that runs the project's test command and refuses the push on non-zero exit.
- A CI workflow (GitHub Actions, or any CI) that runs tests on every PR and blocks merge on red.
- A pre-commit hook for fast-running suites (under a few seconds). Slow suites belong on push or in CI.

The CI gate is the durable backstop. The local hook catches things before they hit CI. Neither replaces the responsibility to run tests during the work; both prevent forgetting at the boundary.

## Why

Tests are the only artifact that can answer "does this change do what I claim it does" without re-reading the code. A change that compiles, type-checks, and was reviewed is still untested. The reviewer assumed the author ran tests; the author assumed the type-checker was enough; the regression ships. The rule closes that loop by making "did you run the tests" a question with a citable answer.

The cost of running an existing suite is seconds to minutes. The cost of debugging a regression after it ships is hours, plus the cost in trust that a doc, a number, or a guarantee in the codebase is reliable. Run the tests.

## Triggers (when to apply this rule)

Apply this rule when:

- Starting any code change task (feature, fix, refactor, dependency bump).
- About to declare a code change done.
- Reviewing whether a change is ready to commit.
- Designing a new project's test infrastructure or CI workflow.
- Auditing an existing project for tests-vs-code coverage.
