import AppCore
import AppModels
import BackendAPI
import Foundation
import Observation

public extension Feature.Search {
    /// The documentation-search view model. Holds the full set of options the UI binds
    /// to (text, the source databases, framework, the per-platform minimum floor, a
    /// result limit, and a scope), runs the query through `Backend.Searching`, and
    /// exposes the result as one `state` enum whose payload is either a flat list of doc
    /// hits (the `docs` scope) or a unified, source-bucketed result (the `everything`
    /// scope). Framework-agnostic, like the other feature view models.
    @Observable
    @MainActor
    final class ViewModel {
        // MARK: Query options (bound by the UI)

        public enum Scope: String, CaseIterable, Sendable {
            case docs
            case everything
        }

        public var scope: Scope = .docs
        public var text: String = ""
        public var sources: Set<Model.Source> = [.appleDocs]
        public var framework: String = ""
        public var minIOS: String = ""
        public var minMacOS: String = ""
        public var minSwift: String = ""
        public var limit: Int = 20

        // MARK: Result state

        public enum Outcome: Sendable {
            case docs([Model.DocHit])
            case everything(Model.UnifiedResults)
        }

        public enum State: Sendable {
            case idle
            case loading
            case loaded(Outcome)
            case failed(String)
        }

        public private(set) var state: State = .idle

        /// Flat doc hits (the `docs` scope), or empty otherwise.
        public var results: [Model.DocHit] {
            if case let .loaded(.docs(hits)) = state { hits } else { [] }
        }

        /// The unified result (the `everything` scope), or nil otherwise.
        public var unified: Model.UnifiedResults? {
            if case let .loaded(.everything(result)) = state { result } else { nil }
        }

        public var isLoading: Bool {
            if case .loading = state { true } else { false }
        }

        public var errorMessage: String? {
            if case let .failed(message) = state { message } else { nil }
        }

        public var hasRun: Bool {
            if case .idle = state { false } else { true }
        }

        private let backend: any Backend.Searching
        private var task: Task<Void, Never>?

        public init(backend: any Backend.Searching) {
            self.backend = backend
        }

        public func toggle(_ source: Model.Source) {
            if sources.contains(source) { sources.remove(source) } else { sources.insert(source) }
        }

        private var floor: Model.PlatformFloor {
            Model.PlatformFloor(
                iOS: minIOS.isEmpty ? nil : minIOS,
                macOS: minMacOS.isEmpty ? nil : minMacOS,
                swift: minSwift.isEmpty ? nil : minSwift,
            )
        }

        /// Run the current scope's query, cancelling any query already in flight.
        public func run() {
            task?.cancel()
            state = .loading
            switch scope {
            case .docs:
                let query = Model.DocsQuery(
                    text: text, sources: sources, framework: framework.isEmpty ? nil : framework,
                    floor: floor, limit: limit,
                )
                task = Task { [weak self] in await self?.load(query) }
            case .everything:
                let query = Model.UnifiedQuery(
                    text: text, framework: framework.isEmpty ? nil : framework,
                    floor: floor, limitPerSource: limit,
                )
                task = Task { [weak self] in await self?.loadEverything(query) }
            }
        }

        /// Internal so a test can drive a docs query deterministically.
        func load(_ query: Model.DocsQuery) async {
            do {
                let hits = try await backend.searchDocs(query)
                if Task.isCancelled { return }
                state = .loaded(.docs(hits))
            } catch {
                if Task.isCancelled { return }
                state = .failed(error.localizedDescription)
            }
        }

        /// Internal so a test can drive a unified query deterministically.
        func loadEverything(_ query: Model.UnifiedQuery) async {
            do {
                let result = try await backend.searchEverything(query)
                if Task.isCancelled { return }
                state = .loaded(.everything(result))
            } catch {
                if Task.isCancelled { return }
                state = .failed(error.localizedDescription)
            }
        }
    }
}
