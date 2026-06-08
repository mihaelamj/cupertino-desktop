import AppCore
import AppModels
import BackendAPI
import Foundation
import Observation
import PresentationBridge

public extension Feature.FrameworkBrowser {
    /// The framework sidebar's view model: loads `listFrameworks()` and exposes the
    /// result as a single `state` enum that both UI shells bind to. It is the
    /// framework-agnostic seam, SwiftUI and AppKit render it identically and differ
    /// only in view code (docs/DESIGN.md, the parallel seam-discovery note).
    ///
    /// It depends on the **narrow** backend slices it uses (`Connecting`,
    /// `FrameworkBrowsing`), not the whole `Backend.Documentation`, so a test can
    /// inject a tiny fake with no transport.
    @Observable
    @MainActor
    final class ViewModel {
        /// Single source of truth for the load. An enum keeps invalid combinations
        /// (loading AND failed) unrepresentable (docs/rules/view-models.md).
        public typealias LoadState = Presentation.LoadState<[Model.Framework]>

        public private(set) var state: LoadState = .idle

        /// The loaded frameworks, or empty in any other state. Derived, never stored
        /// alongside `state`.
        public var frameworks: [Model.Framework] {
            if case let .loaded(frameworks) = state { frameworks } else { [] }
        }

        public var isLoading: Bool {
            if case .loading = state { true } else { false }
        }

        public var errorMessage: String? {
            if case let .failed(message) = state { message } else { nil }
        }

        /// The backend connection status, derived from the load lifecycle, for the
        /// connection-status indicator: connecting until the framework list arrives,
        /// connected once it does, failed on error.
        public enum ConnectionState: Sendable, Equatable {
            case connecting
            case connected
            case failed
        }

        public var connectionState: ConnectionState {
            switch state {
            case .idle, .loading: .connecting
            case .loaded: .connected
            case .failed: .failed
            }
        }

        private let backend: any Backend.Connecting & Backend.FrameworkBrowsing & Backend.Searching & Backend.DocumentReading
        private var loadTask: Task<Void, Never>?
        private var didConnect = false

        public init(backend: any Backend.Connecting & Backend.FrameworkBrowsing & Backend.Searching & Backend.DocumentReading) {
            self.backend = backend
        }

        /// Load the list once, on the view's first appearance. Connecting the backend
        /// happens here only because this is the single feature that talks to it; the
        /// connect lifecycle is the seam to lift into a shared coordinator when a
        /// second feature appears (docs/DESIGN.md). The task holds `self` weakly, so a
        /// dismissed view's in-flight load cannot keep the model alive.
        public func onAppeared() {
            guard case .idle = state else { return }
            // Move out of `.idle` synchronously so a second onAppeared (before the task
            // body runs) is rejected by the guard above, rather than starting a second load.
            state = .loading
            loadTask = Task { [weak self] in await self?.load() }
        }

        /// Re-run after a failure (a Retry affordance in the views).
        public func onRetried() {
            loadTask?.cancel()
            state = .idle
            onAppeared()
        }

        /// Internal (not private) so a test can drive the load deterministically via
        /// `@testable import` without depending on task-scheduling timing.
        func load() async {
            state = .loading
            do {
                // Connect once. If a prior connect succeeded but the list call failed, a
                // retry must not reconnect (that would spawn a second `cupertino serve`);
                // if connect itself threw, `didConnect` stays false and a retry reconnects.
                if !didConnect {
                    try await backend.connect()
                    didConnect = true
                }
                let frameworks = try await backend.listFrameworks()
                if Task.isCancelled { return }
                state = .loaded(frameworks)
            } catch {
                if Task.isCancelled { return }
                state = .failed(error.localizedDescription)
            }
        }

        // MARK: Selected-document reading (the detail column)

        public enum DocumentState: Sendable {
            case empty
            case loading
            case loaded(Model.DocPage)
            case failed(String)
        }

        public private(set) var documentState: DocumentState = .empty

        public var selectedMarkdown: String? {
            if case let .loaded(page) = documentState { page.markdown } else { nil }
        }

        public var selectedDocumentTitle: String? {
            if case let .loaded(page) = documentState { page.title } else { nil }
        }

        public var isLoadingDocument: Bool {
            if case .loading = documentState { true } else { false }
        }

        public var documentError: String? {
            if case let .failed(message) = documentState { message } else { nil }
        }

        private var docTask: Task<Void, Never>?

        /// Load a document for the selected framework, or clear when nothing is
        /// selected. The shells call this when the sidebar selection changes, so the
        /// detail column shows real document content rather than just the id.
        public func selectFramework(_ id: String?) {
            let previous = docTask
            previous?.cancel()
            guard let id else {
                docTask = nil
                documentState = .empty
                return
            }
            documentState = .loading
            // Serialize against the previous load: wait for it to finish before touching the
            // backend. Cancelling the Task stops us acting on its result, but the in-flight
            // request keeps running on the shared subprocess client, so without this barrier
            // walking the list while a page loads fires overlapping reads on one stdio client
            // and races (an intermittent crash). The latest selection still wins: the chain is
            // serial and each superseded load bails on its cancellation check.
            docTask = Task { [weak self] in
                await previous?.value
                guard !Task.isCancelled else { return }
                await self?.loadDocument(framework: id)
            }
        }

        /// Open an arbitrary document by URI in the detail column, replacing the current
        /// one. Used when a link inside a rendered document is tapped (e.g. a "Mentioned
        /// in" entry), so the reader can follow it without going through the sidebar.
        public func openDocument(_ uri: Model.DocURI) {
            let previous = docTask
            previous?.cancel()
            documentState = .loading
            // Same serialization as selectFramework: no overlapping reads on the shared client.
            docTask = Task { [weak self] in
                await previous?.value
                guard !Task.isCancelled else { return }
                await self?.readDocument(uri)
            }
        }

        /// Test hook: await the in-flight document load so tests are deterministic without
        /// polling. Internal, used only by the feature's tests.
        func awaitDocumentLoad() async {
            await docTask?.value
        }

        /// Read a document by URI into the detail. Internal so a test can drive it.
        func readDocument(_ uri: Model.DocURI) async {
            do {
                let page = try await backend.readDocument(uri)
                if Task.isCancelled { return }
                documentState = .loaded(page)
            } catch {
                if Task.isCancelled { return }
                documentState = .failed(error.localizedDescription)
            }
        }

        /// Find a document in the framework (a search scoped to it) and read the first
        /// hit. This works for both the mock reader and the real engine, rather than
        /// assuming a synthetic URI. Internal so a test can drive it deterministically.
        func loadDocument(framework id: String) async {
            do {
                // Query the framework name (scoped to the framework), NOT an empty string:
                // live cupertino is FTS5 and rejects an empty query ("Query cannot be
                // empty"), so selecting a framework loaded nothing. The framework name
                // surfaces its overview page as the top hit.
                let hits = try await backend.searchDocs(Model.DocsQuery(text: id, framework: id, limit: 1))
                guard let uri = hits.first?.uri else {
                    if Task.isCancelled { return }
                    documentState = .empty
                    return
                }
                let page = try await backend.readDocument(uri)
                if Task.isCancelled { return }
                documentState = .loaded(page)
            } catch {
                if Task.isCancelled { return }
                documentState = .failed(error.localizedDescription)
            }
        }
    }
}
