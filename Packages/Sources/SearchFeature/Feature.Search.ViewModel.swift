import AppCore
import AppModels
import BackendAPI
import Foundation
import Observation

public extension Feature.Search {
    /// The documentation-search view model: holds the full set of `searchDocs` options
    /// the UI binds to (text, the source databases, framework, the per-platform minimum
    /// floor, and a result limit), runs the query through `Backend.Searching`, and
    /// exposes the result as one `state` enum. Framework-agnostic, like the other
    /// feature view models, so every shell renders it identically.
    @Observable
    @MainActor
    final class ViewModel {
        // MARK: Query options (bound by the UI)

        public var text: String = ""
        public var sources: Set<Model.Source> = [.appleDocs]
        public var framework: String = ""
        public var minIOS: String = ""
        public var minMacOS: String = ""
        public var minSwift: String = ""
        public var limit: Int = 20

        // MARK: Result state

        public enum State: Sendable {
            case idle
            case loading
            case loaded([Model.DocHit])
            case failed(String)
        }

        public private(set) var state: State = .idle

        public var results: [Model.DocHit] {
            if case let .loaded(hits) = state { hits } else { [] }
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

        /// Toggle a source database in or out of the query.
        public func toggle(_ source: Model.Source) {
            if sources.contains(source) { sources.remove(source) } else { sources.insert(source) }
        }

        /// Build a `DocsQuery` from the current options and run it, cancelling any query
        /// already in flight so a slow result never lands stale.
        public func run() {
            task?.cancel()
            state = .loading
            let query = Model.DocsQuery(
                text: text,
                sources: sources,
                framework: framework.isEmpty ? nil : framework,
                floor: Model.PlatformFloor(
                    iOS: minIOS.isEmpty ? nil : minIOS,
                    macOS: minMacOS.isEmpty ? nil : minMacOS,
                    swift: minSwift.isEmpty ? nil : minSwift,
                ),
                limit: limit,
            )
            task = Task { [weak self] in await self?.load(query) }
        }

        /// Internal so a test can drive a query deterministically.
        func load(_ query: Model.DocsQuery) async {
            do {
                let hits = try await backend.searchDocs(query)
                if Task.isCancelled { return }
                state = .loaded(hits)
            } catch {
                if Task.isCancelled { return }
                state = .failed(error.localizedDescription)
            }
        }
    }
}
