# SwiftUI ViewModel Architecture Rules

ViewModel rules for the planned Tiledown native editor. ViewModels are thin coordination layers between Views and Services. They orchestrate business logic without containing it, maintain reactive UI state via `@Observable`, and stay testable through dependency injection.

## Mental model

ViewModel = Coordinator (NOT a business-logic container)

- Services: business logic
- ViewModel: coordination + UI transformation
- View: pure presentation

## Core rules

### Rule 1: ViewModel as coordinator

- MUST delegate business logic to services
- MUST NOT contain business rules or external access
- Coordinate between layers only

### Rule 2: State management

- MUST use `private(set)` for mutable state
- MUST use enums for loading/async states (idle, loading, loaded, failed)
- MUST derive computed state (no duplication)
- MUST use `@MainActor` on the class definition
- State machines for complex flows (prefer enum over multiple booleans)

### Rule 3: Dependency injection

- MUST inject collaborators (see docs/rules/dependency-injection.md)
- SHOULD prefer struct-based dependencies over protocols where practical
- NO global singletons

### Rule 4: Task management

- MUST support cancellation
- MUST track loading states
- MUST handle errors gracefully
- Clean up in deinit

### Rule 5: Method naming

- View-triggered: `on` prefix (e.g., `onTappedItem`)
- Describe the user action, not the implementation
- Internal methods: standard naming

### Rule 6: Testing design

- MUST be testable without UI
- MUST verify state transitions
- NO timing dependencies

## Decision tree: code belongs in ViewModel?

```
Code belongs in ViewModel?
├─ UI state management? → YES
├─ Coordinating services? → YES
├─ Transforming for UI? → YES
├─ Business logic? → NO (Service)
├─ Data persistence? → NO (Repository)
└─ Complex computation? → NO (Domain Service)
```

## Patterns

### Basic structure

```swift
enum LoadingState<T: Equatable>: Equatable {
    case idle
    case loading
    case loaded(T)
    case failed(Error)

    static func == (lhs: LoadingState<T>, rhs: LoadingState<T>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading): return true
        case let (.loaded(l), .loaded(r)): return l == r
        case let (.failed(l), .failed(r)): return l.localizedDescription == r.localizedDescription
        default: return false
        }
    }
}

@Observable @MainActor
final class TileListViewModel {
    // State (always private(set))
    private(set) var state: LoadingState<[Tile]> = .idle

    // Computed (derive, don't duplicate)
    var tiles: [Tile] {
        if case .loaded(let tiles) = state { return tiles }
        return []
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var error: Error? {
        if case .failed(let error) = state { return error }
        return nil
    }

    // Injected dependencies
    private let service: TileService
    private var loadTask: Task<Void, Never>?

    init(service: TileService) {
        self.service = service
    }

    deinit { loadTask?.cancel() }

    // User actions (on prefix)
    func onAppeared() {
        loadTask = Task { await loadTiles() }
    }

    // Private implementation
    private func loadTiles() async {
        state = .loading
        do {
            let tiles = try await service.fetchTiles()
            state = .loaded(tiles)
        } catch {
            state = .failed(error)
        }
    }
}
```

### State machine

```swift
enum SessionState: Equatable {
    case signedOut, signingIn, signedIn(User), failed(Error)
}

@Observable @MainActor
final class SessionViewModel {
    private(set) var state: SessionState = .signedOut

    private let sessionService: SessionService

    init(sessionService: SessionService) {
        self.sessionService = sessionService
    }

    var isAuthenticated: Bool {
        if case .signedIn = state { true } else { false }
    }

    func onSubmittedSignIn(email: String, password: String) async {
        guard case .signedOut = state else { return }
        state = .signingIn

        do {
            let user = try await sessionService.signIn(email, password)
            state = .signedIn(user)
        } catch {
            state = .failed(error)
        }
    }
}
```

### Search debounce

```swift
@Observable @MainActor
final class SearchViewModel {
    private(set) var searchText = ""
    private(set) var results: [SearchResult] = []
    private var searchTask: Task<Void, Never>?

    private let service: SearchService

    init(service: SearchService) {
        self.service = service
    }

    func onChangedSearchText(_ text: String) {
        searchText = text
        searchTask?.cancel()

        guard !text.isEmpty else {
            results = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            results = try await service.search(text)
        }
    }
}
```

## Anti-patterns

### Business logic in ViewModel

```swift
// Wrong: business logic in ViewModel
func computeLayout(for tile: Tile) -> Layout {
    // Belongs in a service
}

// Right: delegate to service
func onRequestedLayout(for tile: Tile) async -> Layout {
    await layoutService.layout(for: tile)
}
```

### Public mutable state

```swift
// Wrong: anyone can mutate
var tiles: [Tile] = []

// Right: private setter
private(set) var tiles: [Tile] = []
```

### Scattered state

```swift
// Wrong: scattered state makes invalid states possible
private(set) var tiles: [Tile] = []
private(set) var isLoading = false
private(set) var error: Error?
// Can be: loading=true AND error != nil (invalid)

// Right: single source of truth with enum
enum LoadingState<T: Equatable>: Equatable {
    case idle, loading, loaded(T), failed(Error)
}
private(set) var state: LoadingState<[Tile]> = .idle
```

### View reference in ViewModel

```swift
// Wrong: ViewModel knows about View
weak var view: MyView?

// Right: ViewModel exposes state
private(set) var errorMessage: String?
```

## Testing

```swift
@Test("Search updates correctly")
func searchUpdate() async {
    let service = SearchService(search: { _ in [.init(id: "1")] })
    let vm = SearchViewModel(service: service)

    // Initial state
    #expect(vm.results.isEmpty)

    // Trigger search
    await vm.onChangedSearchText("query")

    // Wait for debounce
    try? await Task.sleep(for: .milliseconds(400))

    // Verify
    #expect(vm.results.count == 1)
}
```

## Checklist

- [ ] All state uses `private(set)`
- [ ] Dependencies injected through `init`
- [ ] Business logic in services
- [ ] User actions prefixed with `on`
- [ ] Tasks cancellable
- [ ] Errors transformed for UI
- [ ] No force unwrapping
- [ ] No view references
- [ ] Computed properties for derived state
- [ ] Task cleanup in deinit
