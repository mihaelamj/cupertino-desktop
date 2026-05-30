import AppCore
import AppModels
import BackendAPI
import Foundation
import Observation

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
        public enum LoadState: Sendable {
            case idle
            case loading
            case loaded([Model.Framework])
            case failed(String)
        }

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

        /// Read the overview page for the selected framework, or clear when nothing is
        /// selected. The shells call this when the sidebar selection changes, so the
        /// detail column shows real document content rather than just the id.
        public func selectFramework(_ id: String?) {
            docTask?.cancel()
            guard let id else {
                documentState = .empty
                return
            }
            documentState = .loading
            docTask = Task { [weak self] in await self?.loadDocument(framework: id) }
        }

        /// Find a document in the framework (a search scoped to it) and read the first
        /// hit. This works for both the mock reader and the real engine, rather than
        /// assuming a synthetic URI.
        private func loadDocument(framework id: String) async {
            do {
                let hits = try await backend.searchDocs(Model.DocsQuery(text: "", framework: id, limit: 1))
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
