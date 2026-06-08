import AppCore
import AppModels
import BackendAPI
import Foundation
import Observation
import PresentationBridge

public extension Feature.Search {
    /// The documentation-search view model. Holds the full set of options the UI binds
    /// to (text, source ids, framework, the per-platform minimum floor, a
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

        public typealias State = Presentation.LoadState<Outcome>

        public private(set) var state: State = .idle

        /// Flat doc hits (the `docs` scope), or empty otherwise.
        public var results: [Model.DocHit] {
            if case let .loaded(.docs(hits)) = state { hits } else { [] }
        }

        /// The `docs`-scope hits grouped into a `framework -> hit` tree. This is the shared,
        /// framework-agnostic Logical Presentation each shell reifies natively (SwiftUI
        /// sections, AppKit/UIKit header + leaf rows). See cupertino-desktop #51.
        public var docsTree: [ResultNode] {
            Feature.Search.resultTree(docs: results)
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

        private let backend: any Backend.Searching & Backend.DocumentReading
        private var task: Task<Void, Never>?

        public init(backend: any Backend.Searching & Backend.DocumentReading) {
            self.backend = backend
        }

        /// Read a document by URI so a tapped result can open its page.
        public func readPage(_ uri: Model.DocURI) async throws -> Model.DocPage {
            try await backend.readDocument(uri)
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

        /// Run the current scope's query now, cancelling any query already in flight.
        public func run() {
            task?.cancel()
            state = .loading
            task = Task { [weak self] in await self?.execute() }
        }

        /// Run after a short delay, coalescing rapid keystrokes so live search does not
        /// fire a query per character (and does not hammer a real backend). Existing
        /// results stay on screen until the new ones arrive, so there is no flicker.
        public func runDebounced() {
            task?.cancel()
            task = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else { return }
                await execute()
            }
        }

        private func execute() async {
            switch scope {
            case .docs:
                await load(Model.DocsQuery(
                    text: text, sources: sources, framework: framework.isEmpty ? nil : framework,
                    floor: floor, limit: limit,
                ))
            case .everything:
                await loadEverything(Model.UnifiedQuery(
                    text: text, framework: framework.isEmpty ? nil : framework,
                    floor: floor, limitPerSource: limit,
                ))
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
