# Verification Before Completion

Never claim work is complete, fixed, or passing without fresh evidence from the relevant verification commands. Every completion claim must be backed by command output captured in the same response.

## Core rules

### Rule 1: No claim without fresh evidence

Run the verification command in the same response where you make the claim.
- MUST run the command, not assume it from earlier output
- MUST quote the relevant lines (exit code, failure count, error summary)
- MUST NOT extrapolate ("the lint passed earlier so the build should pass")
- MUST NOT use phrases like "should pass", "looks good", "I believe it works"

### Rule 2: Match the command to the claim
| Claim | Required command | What to confirm |
|---|---|---|
| "Build succeeds" | `swift build` (or `xcodebuild build`) | exit 0, no compiler errors |
| "Tests pass" | `swift test` (or target-specific `swift test --filter <Suite>`) | 0 failures, expected count of tests ran |
| "Lint clean" | `swiftlint --config .swiftlint.yml` | 0 errors (warnings reported separately) |
| "Format clean" | `swiftformat . --config .swiftformat --lint` | exit 0 |
| "Bug fixed" | the test that reproduced the bug | now passes; state which test |
| "Refactor preserved behavior" | full test suite | 0 failures |
| "Package compiles in isolation" | `swift build --target <TargetName>` | exit 0 |

If you do not have the required command, state that explicitly. Do not guess.

### Rule 3: Failure reporting

Report partial results honestly.
- MUST list which checks were run, which passed, which failed, which were skipped
- MUST NOT bundle a partial run under a "done" headline
- MUST quote the first 3 to 5 errors verbatim if any check failed

### Rule 4: Pre-commit gate

Run, in order, before claiming a change is commit-ready:
```bash
swiftformat . --config .swiftformat
swiftlint --config .swiftlint.yml
cd Packages && swift build && swift test
```
Cite each step's outcome. Git hooks may run a subset; that is not a substitute for explicit citation in the response.

### Rule 5: Boundary of "done"

**Done means**: the change is staged, the four commands above have output that confirms success, and any user-visible behavior the change affects has been exercised (UI smoke for screen changes, integration test for engine/API changes, etc.).

**Not done**: typecheck succeeded, code looks right, tests "should" pass, "ready to commit" without running the gate.

## Mechanical enforcement: local and CI

Every gate a machine can decide runs in two places: a local git hook, so a
violation is never committed, and GitHub CI, so a violation is never merged even
if the local hook was skipped. The local hook catches it early; CI is the backstop.

| Gate | Local hook | CI job |
|---|---|---|
| No em dash / no tool attribution (commit message) | `.githooks/commit-msg` | `style` |
| No em dash / no tool attribution (file content) | `.githooks/pre-commit` | `style` (`scripts/check-style.sh`) |
| One type per file | `.githooks/pre-push` (`scripts/check-namespacing.sh`) | `style` |
| Format clean | `.githooks/pre-push` (`swiftformat --lint`) | `swift-macos` |
| No force-unwrap, lint clean | `.githooks/pre-push` (`swiftlint --strict`) | `swift-macos` |
| Build and tests pass (macOS and Linux) | `.githooks/pre-push` | `swift-macos`, `swift-linux` |

Enable the local hooks once after cloning:

```bash
git config core.hooksPath .githooks
```

The Swift gates are inert until `Packages/Package.swift` exists; the style and
namespacing gates run now. CI lives in `.github/workflows/ci.yml`.

## Anti-Patterns

- "All set" with no command output in the response
- "Tests pass" while the run was partial (`swift test --filter` against a single suite while another suite is broken)
- Treating successful `swift build` as proof tests pass
- Quoting old output from earlier in the conversation as if it were fresh
- Marking a task item complete before running the gate
