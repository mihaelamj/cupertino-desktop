# Swift Testing Framework Rules

How to write tests for Tiledown: focused, isolated, deterministic suites built on the Swift Testing framework.

Write comprehensive tests using the Swift Testing framework (`@Test`). Tests must be focused, isolated, deterministic, and leverage modern Swift Testing features for maximum reliability and maintainability. The core engine (`TileKit`, the `Tile` / `TileType` primitives, the `TileDown` namespace) is non-UI and is exercised with plain unit and integration tests. The SwiftUI/ViewInspector/snapshot patterns below apply to the planned native macOS/iOS app, not to the engine.

The `withDependencies` overrides shown in the patterns below assume the Point-Free Dependencies library, whose adoption is an open question; see [../decisions/point-free-dependencies.md](../decisions/point-free-dependencies.md). Where Tiledown does not use that library, control collaborators through plain constructor injection instead; the test-isolation and determinism rules apply either way.

## Core rules

### Rule 1: Swift Testing framework usage

Use modern Swift Testing:
- MUST use `@Test` attribute for test methods
- MUST use `#expect` macro for assertions
- MUST use parameterized tests for multiple scenarios
- MUST NOT use XCTest unless absolutely required

### Rule 2: Dependency isolation

Control dependencies in tests:
- MUST control collaborators in tests (via `withDependencies` if the Dependencies library is adopted, otherwise via constructor injection)
- MUST provide deterministic test values
- MUST isolate tests from external systems
- MUST NOT use live dependencies in tests

### Rule 3: Test organization

Structure tests clearly:
- MUST use `@Suite` for logical grouping
- MUST name tests descriptively
- MUST test one behavior per test
- MUST NOT create kitchen sink tests

### Rule 4: Async testing

Handle concurrency properly:
- MUST use async/await for async tests
- MUST avoid race conditions
- MUST use structured concurrency
- MUST NOT use arbitrary delays

### Rule 5: Test pyramid

Follow testing hierarchy:
- MUST have ~70% unit tests (fast, isolated)
- MUST have ~20% integration tests (component interaction)
- MUST have ~10% UI/E2E tests (critical paths)
- MUST NOT invert the pyramid

## TEST TYPE DECISION TREE

```
What are you testing?
├─ Pure logic/calculations?
│   └─ Unit Test → Direct function tests
├─ State management?
│   └─ Unit Test → ViewModel/Model tests
├─ Component interaction?
│   └─ Integration Test → Multi-component tests
├─ User interface (planned native app)?
│   ├─ Visual correctness? → Snapshot Test
│   └─ User interaction? → ViewInspector Test
└─ Complete user flow?
    └─ E2E Test → Full flow test
```

## TESTING PATTERNS

### Pattern 1: Basic Test Structure

```swift
// RULE: Each test file follows this structure
import Testing
import Dependencies
@testable import TileKit

@Suite("Tile Rendering Tests")
struct TileRenderingTests {
    // RULE: Group related tests in nested suites
    @Suite("Markdown Tile")
    struct MarkdownTileTests {
        // RULE: Shared test data at suite level
        let fixture = TileFixture()

        @Test("Clear description of what should happen")
        func renderScenario() async throws {
            // RULE: Arrange dependencies
            let sut = withDependencies {
                $0.fileClient.read = { _ in self.fixture.markdown }
            } operation: {
                TileRenderer()
            }

            // RULE: Act on the system
            let result = try await sut.render(.markdown)

            // RULE: Assert the outcome
            #expect(result == expectedHTML)
        }
    }
}
```

### Pattern 2: Parameterized Testing

```swift
// RULE: Use parameterized tests for similar scenarios
@Test("Validates different slug formats", arguments: [
    ("hello-world", true),
    ("Hello World", false),
    ("", false),
    ("trailing-", false),
    ("-leading", false)
])
func slugValidation(slug: String, isValid: Bool) {
    let validator = SlugValidator()
    #expect(validator.isValid(slug) == isValid)
}

// RULE: Use table-driven tests for complex scenarios
struct TestCase {
    let input: String
    let expectedOutput: String
    let shouldThrow: Bool
}

@Test("Processes various inputs correctly", arguments: [
    TestCase(input: "hello", expectedOutput: "HELLO", shouldThrow: false),
    TestCase(input: "", expectedOutput: "", shouldThrow: false),
    TestCase(input: "123", expectedOutput: "", shouldThrow: true)
])
func processingScenarios(testCase: TestCase) async throws {
    let processor = TextProcessor()

    if testCase.shouldThrow {
        await #expect(throws: ProcessingError.self) {
            try await processor.process(testCase.input)
        }
    } else {
        let result = try await processor.process(testCase.input)
        #expect(result == testCase.expectedOutput)
    }
}
```

### Pattern 3: ViewModel Testing (planned native app)

```swift
// RULE: Test ViewModels with controlled dependencies
@Suite("TilePreviewViewModel Tests")
struct TilePreviewViewModelTests {
    @Test("Initial state is correct")
    func initialState() {
        let viewModel = TilePreviewViewModel()

        #expect(viewModel.tile == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.error == nil)
    }

    @Test("Loading a tile shows loading states")
    func loadingStateTransitions() async {
        // RULE: Track state changes
        var states: [LoadingState] = []

        let viewModel = withDependencies {
            $0.tileClient.fetch = { _ in
                try await Task.sleep(for: .milliseconds(50))
                return .mock
            }
        } operation: {
            TilePreviewViewModel()
        }

        // RULE: Observe state changes
        let observation = viewModel.observe(\.isLoading) { loading in
            states.append(loading ? .loading : .idle)
        }

        await viewModel.loadTile(id: UUID())

        #expect(states == [.idle, .loading, .idle])
        #expect(viewModel.tile == .mock)
    }

    @Test("Handles errors gracefully")
    func errorHandling() async {
        struct TestError: Error, Equatable {}

        let viewModel = withDependencies {
            $0.tileClient.fetch = { _ in throw TestError() }
            $0.logger.log = { _, _ in } // Silence logs in tests
        } operation: {
            TilePreviewViewModel()
        }

        await viewModel.loadTile(id: UUID())

        #expect(viewModel.error as? TestError == TestError())
        #expect(viewModel.tile == nil)
        #expect(!viewModel.isLoading)
    }
}
```

### Pattern 4: Async Stream Testing

```swift
// RULE: Test async streams properly
@Suite("File Watcher Tests")
struct FileWatcherTests {
    @Test("Processes a change stream")
    func changeStream() async throws {
        let changes = ["post-a.md", "post-b.md", "index.md"]
        var received: [String] = []

        let viewModel = withDependencies {
            $0.watcherClient.changes = {
                AsyncStream { continuation in
                    for change in changes {
                        continuation.yield(change)
                    }
                    continuation.finish()
                }
            }
        } operation: {
            RebuildViewModel()
        }

        // RULE: Collect all changes
        for await change in viewModel.changeStream {
            received.append(change)
        }

        #expect(received == changes)
    }

    @Test("Handles stream errors")
    func streamErrorHandling() async throws {
        struct StreamError: Error {}

        let viewModel = withDependencies {
            $0.watcherClient.changes = {
                AsyncThrowingStream { continuation in
                    continuation.yield("first.md")
                    continuation.finish(throwing: StreamError())
                }
            }
        } operation: {
            RebuildViewModel()
        }

        var changes: [String] = []
        var errorCaught = false

        do {
            for try await change in viewModel.changeStream {
                changes.append(change)
            }
        } catch is StreamError {
            errorCaught = true
        }

        #expect(changes == ["first.md"])
        #expect(errorCaught)
    }
}
```

### Pattern 5: View Testing with ViewInspector (planned native app)

```swift
// RULE: Test SwiftUI views in isolation
import ViewInspector

@Suite("TileCardView Tests")
struct TileCardViewTests {
    @Test("Displays tile information")
    func tileDisplay() throws {
        let tile = Tile(title: "Hello World", type: .markdown)
        let view = TileCardView(tile: tile)

        let sut = try view.inspect()

        // RULE: Find and verify UI elements
        let titleText = try sut.find(text: "Hello World")
        #expect(try titleText.string() == "Hello World")

        let typeText = try sut.find(text: "Markdown")
        #expect(try typeText.string() == "Markdown")
    }

    @Test("Interaction triggers callbacks")
    func buttonInteraction() throws {
        var tapped = false
        let view = TileCardView(
            tile: .mock,
            onTap: { tapped = true }
        )

        let sut = try view.inspect()
        let button = try sut.find(button: "Open")
        try button.tap()

        #expect(tapped)
    }
}
```

### Pattern 6: Snapshot Testing (planned native app)

```swift
// RULE: Use snapshot tests for visual regression
import SnapshotTesting

@Suite("Visual Regression Tests")
struct VisualRegressionTests {
    @Test("Tile list appearance", arguments: [
        ("iPhone", ViewImageConfig.iPhone13Pro),
        ("iPad", ViewImageConfig.iPadPro11),
        ("SE", ViewImageConfig.iPhoneSe)
    ])
    func deviceSnapshots(device: String, config: ViewImageConfig) {
        let view = TileListView(tiles: .mockArray)

        assertSnapshot(
            matching: view,
            as: .image(layout: .device(config: config)),
            named: device
        )
    }

    @Test("Dark mode support")
    func darkMode() {
        let view = ContentView()
            .preferredColorScheme(.dark)

        assertSnapshot(
            matching: view,
            as: .image(traits: .init(userInterfaceStyle: .dark))
        )
    }
}
```

## DEPENDENCY MOCKING PATTERNS

### Pattern 1: Test Dependency Configuration

```swift
// RULE: Create reusable test configurations
extension DependencyValues {
    static func testValue(
        configuring: (inout DependencyValues) -> Void = { _ in }
    ) -> DependencyValues {
        var dependencies = DependencyValues()

        // RULE: Set safe defaults for all dependencies
        dependencies.tileClient = .noop
        dependencies.date.now = Date(timeIntervalSince1970: 0)
        dependencies.uuid = .incrementing
        dependencies.mainQueue = .immediate

        // Apply custom configuration
        configuring(&dependencies)

        return dependencies
    }
}

// RULE: Use in tests for consistency
@Test("Example usage")
func testWithConfiguration() async {
    let viewModel = withDependencies {
        $0 = .testValue { deps in
            deps.tileClient.fetch = { _ in .mock }
        }
    } operation: {
        TileViewModel()
    }

    await viewModel.loadTile()
    #expect(viewModel.tile == .mock)
}
```

### Pattern 2: Mock Implementations

```swift
// RULE: Create predictable mock implementations
extension TileClient {
    static let noop = TileClient(
        fetch: { _ in throw CancellationError() },
        write: { _ in throw CancellationError() },
        delete: { _ in throw CancellationError() }
    )

    static func succeeding(
        tile: Tile = .mock,
        delay: Duration = .zero
    ) -> TileClient {
        TileClient(
            fetch: { _ in
                if delay > .zero {
                    try await Task.sleep(for: delay)
                }
                return tile
            },
            write: { _ in
                if delay > .zero {
                    try await Task.sleep(for: delay)
                }
            },
            delete: { _ in
                if delay > .zero {
                    try await Task.sleep(for: delay)
                }
            }
        )
    }

    static func failing(
        error: Error = TestError()
    ) -> TileClient {
        TileClient(
            fetch: { _ in throw error },
            write: { _ in throw error },
            delete: { _ in throw error }
        )
    }
}
```

## TESTING ANTI-PATTERNS

### DON'T: Test implementation details
```swift
// WRONG: Testing private state
@Test
func badTest() {
    let viewModel = TileViewModel()

    // Don't access private properties
    let mirror = Mirror(reflecting: viewModel)
    // This is brittle and breaks encapsulation
}

// RIGHT: Test behavior through public API
@Test
func goodTest() {
    let viewModel = TileViewModel()

    viewModel.updateTitle("New Title")
    #expect(viewModel.displayTitle == "New Title")
}
```

### DON'T: Use arbitrary delays
```swift
// WRONG: Race condition waiting
@Test
func badAsyncTest() async {
    let viewModel = SearchViewModel()
    viewModel.search("query")

    // Arbitrary delay - flaky!
    try? await Task.sleep(for: .seconds(1))

    #expect(!viewModel.results.isEmpty)
}

// RIGHT: Proper synchronization
@Test
func goodAsyncTest() async {
    let viewModel = withDependencies {
        $0.tileClient.search = { _ in [.mock] }
    } operation: {
        SearchViewModel()
    }

    await viewModel.search("query")
    #expect(viewModel.results == [.mock])
}
```

### DON'T: Share state between tests
```swift
// WRONG: Shared mutable state
class SharedCache {
    static let shared = SharedCache()
    var data: [String: Any] = [:]
}

@Test
func badTest1() {
    SharedCache.shared.data["key"] = "value"
}

@Test
func badTest2() {
    // This test depends on badTest1!
    let value = SharedCache.shared.data["key"]
}

// RIGHT: Isolated dependencies
@Test
func goodTest() {
    let cache = withDependencies {
        $0.cacheClient = .previewValue
    } operation: {
        CacheClient()
    }

    // Test is completely isolated
}
```

## Test target placement

### Rule: One test target per source target

Declare a matching `Target.testTarget` for every `Target.target` in `Package.swift`:

```swift
let tileKitTarget = Target.target(
    name: "TileKit",
    dependencies: ["TileDownModels", "FileClient"]
)
let tileKitTestsTarget = Target.testTarget(
    name: "TileKitTests",
    dependencies: ["TileKit"]
)
let tileKitTargets = [tileKitTarget, tileKitTestsTarget]
```

- MUST name the test target `<SourceTarget>Tests` (no other suffix)
- MUST list the source target as a dependency of the test target
- MUST group the source + test target as a pair in a named local sub-array (`let tileKitTargets = [...]`) so platform conditionals and grouping comments stay clean
- MUST NOT skip the test target, even for trivial packages
- MUST NOT define the test target inline in the top-level `targets:` array

### Folder layout

Tiledown is a monorepo from day one: sources live under `Packages/Sources/<SourceTarget>/` and tests under `Packages/Tests/<SourceTarget>Tests/`, mirroring each other:

```
.
├── Packages/
│   ├── Sources/
│   │   └── TileKit/
│   │       └── ...source files...
│   └── Tests/
│       └── TileKitTests/
│           ├── ...test files...
│           └── Mocks/
│               └── ...mock implementations...
```

### Mocks live in the test target, never in the source package

Public test doubles (mocks, fakes, stubs) are placed in `Packages/Tests/<SourceTarget>Tests/Mocks/`, NOT in `Packages/Sources/<SourceTarget>/`. Mocks shipped from `Packages/Sources/` leak into production binaries.

```swift
// Packages/Sources/FileClient/FileClientProtocol.swift
public protocol FileClientProtocol {
    func read(path: String) async throws -> String
}

// Packages/Tests/FileClientTests/Mocks/MockFileClient.swift
public struct MockFileClient: FileClientProtocol {
    public var readResult: Result<String, Error>
    public func read(path: String) async throws -> String {
        try readResult.get()
    }
}
```

The protocol MAY be public (so the mock can implement it). The mock MUST live in the test target.

### Running a single target's tests

```bash
swift test --filter <SourceTarget>Tests
```

## TEST ORGANIZATION CHECKLIST

Before submitting tests, verify:

- [ ] Tests use `@Test` attribute, not XCTest
- [ ] Each test has single, clear purpose
- [ ] Test names describe scenario and outcome
- [ ] Dependencies controlled with `withDependencies`
- [ ] No live network/database calls
- [ ] Async tests use proper concurrency
- [ ] No arbitrary delays or race conditions
- [ ] Test data is deterministic
- [ ] Error cases thoroughly tested
- [ ] Edge cases covered
- [ ] Tests run in isolation
- [ ] Follows test pyramid (70/20/10)
- [ ] Critical paths have E2E tests
- [ ] Visual changes have snapshot tests

## Testing decision flowchart

```
Writing a new test:
├─ Can it be a unit test?
│   ├─ YES → Write focused unit test
│   └─ NO → Why not?
│       ├─ Needs multiple components?
│       │   └─ Write integration test
│       └─ Tests UI (planned native app)?
│           ├─ Visual? → Snapshot test
│           └─ Interaction? → ViewInspector
├─ Is it deterministic?
│   ├─ NO → Fix non-determinism
│   └─ YES → Continue
└─ Does it run fast (<100ms)?
    ├─ NO → Can it be optimized?
    │   ├─ YES → Optimize
    │   └─ NO → Tag as slow
    └─ YES → Good to go
```

## Troubleshooting: stale SwiftPM build artifacts

Before spending time debugging an impossible-looking test failure, check if it's a stale build. Swift 6.2 on recent macOS has a known incremental-build bug where adding, moving, or renaming a method on an `actor` (or any type with concurrency surface) can leave downstream `.o` / `.swiftmodule` files with the old method-table layout. Async dispatch then lands in the wrong slot, reads garbage, and trips a Swift stdlib `_precondition` far from the real call site.

### How to recognise it

All of these together strongly suggest staleness, not a real bug:

- Stack trace points at a stdlib `.swiftinterface` line: "Not enough bits to represent the passed value" or a similar stdlib integer-conversion trap
- Reported crash frame is inside a function that is **not** actually in the call path (linker ICF-folding + symbolizer ambiguity)
- Adding or removing a *trivial* method (even an empty one) toggles the crash
- The same test passes in isolation but fails when run alongside others, or vice versa
- Git bisect blames a commit whose diff has no logical relationship to the trap
- Parallelism toggles (`--parallel / --no-parallel`, `SWIFT_TESTING_PARALLELIZATION_ENABLED=false`) have no effect

### Remedy

```bash
swift package clean && rm -rf .build && swift test
```

Or, if the project has a `Makefile`, run the `test-clean` (or equivalent) target.

CI is not affected; it always builds from scratch. This only bites local development after method-surface changes on actors.

### Dead-end diagnostic paths (do NOT repeat)

- Adding `print` / `FileHandle.standardError.write` to the apparent trap site: the prints never fire because the reported symbol is wrong
- Switching `Int32(x)` to `Int32(clamping: x)`: masks the UInt assertion as a stack canary trap (SIGTRAP to SIGABRT), does not fix it
- Per-commit bisection: will blame the commit that happened to add a method, not the real cause
- Debugging across a test binary rebuild: rebuild resets the staleness, making the bug intermittent

If you've exhausted these paths, the answer is almost always a clean rebuild.
