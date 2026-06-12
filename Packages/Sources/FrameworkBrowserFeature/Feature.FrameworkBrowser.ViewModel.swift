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
    final class ViewModel: Presentation.FrameworkBrowserViewModelProtocol {
        /// Single source of truth for the load. An enum keeps invalid combinations
        /// (loading AND failed) unrepresentable (docs/rules/view-models.md).
        public typealias LoadState = Presentation.FrameworkBrowser.LoadState
        public typealias ConnectionState = Presentation.FrameworkBrowser.ConnectionState

        public private(set) var state: LoadState = .idle
        public private(set) var sources: [Model.Source] = Model.Source.allCases
        private var hierarchyItems: [Model.HierarchyItem] = []
        var hierarchyTask: Task<Void, Never>?

        public var frameworks: [Model.Framework] {
            guard case let .loaded(all) = state else { return [] }

            let list: [Model.Framework]
            if selectedSource == nil {
                list = all
            } else if !hierarchyItems.isEmpty {
                list = hierarchyItems.map { item in
                    Model.Framework(id: item.id, name: item.title, documentCount: 0)
                }
            } else if let source = selectedSource {
                var allWithPlaceholders = all
                let placeholders = [
                    Model.Framework(id: "swift-evolution", name: "Swift Evolution", documentCount: 0),
                    Model.Framework(id: "swift-org", name: "Swift.org Docs", documentCount: 0),
                    Model.Framework(id: "swift-book", name: "Swift Book", documentCount: 0),
                    Model.Framework(id: "samples", name: "Sample Projects", documentCount: 0),
                    Model.Framework(id: "packages", name: "Swift Packages", documentCount: 0),
                    Model.Framework(id: "components", name: "Components", documentCount: 0),
                    Model.Framework(id: "foundations", name: "Foundations", documentCount: 0),
                    Model.Framework(id: "general", name: "General", documentCount: 0),
                    Model.Framework(id: "inputs", name: "Inputs", documentCount: 0),
                    Model.Framework(id: "patterns", name: "Patterns", documentCount: 0),
                    Model.Framework(id: "technologies", name: "Technologies", documentCount: 0),
                ]
                for placeholder in placeholders {
                    let isBelongs = ViewModel.belongs(framework: placeholder, to: source)
                    let isNew = !allWithPlaceholders.contains(where: { $0.id == placeholder.id })
                    if isBelongs, isNew {
                        allWithPlaceholders.append(placeholder)
                    }
                }
                list = allWithPlaceholders.filter { ViewModel.belongs(framework: $0, to: source) }
            } else {
                list = all
            }

            let filteredBySearch: [Model.Framework]
            if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                filteredBySearch = list
            } else {
                let query = searchQuery.lowercased()
                filteredBySearch = list.filter {
                    $0.displayName.lowercased().contains(query) || $0.id.lowercased().contains(query)
                }
            }

            switch sortOrder {
            case .count:
                if selectedSource == nil {
                    return filteredBySearch.sorted {
                        $0.documentCount != $1.documentCount
                            ? $0.documentCount > $1.documentCount
                            : $0.name < $1.name
                    }
                } else {
                    return filteredBySearch
                }
            case .name:
                return filteredBySearch.sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
            }
        }

        let backend: any Backend.Connecting & Backend.FrameworkBrowsing & Backend.Searching & Backend.DocumentReading
        var loadTask: Task<Void, Never>?
        private var didConnect = false
        public var skipAwaitingDocTask = false

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
                async let sourcesFetch = backend.listSources()
                async let frameworksFetch = backend.listFrameworks()
                let (fetchedSources, fetchedFrameworks) = try await (sourcesFetch, frameworksFetch)
                if Task.isCancelled { return }
                sources = fetchedSources
                state = .loaded(fetchedFrameworks)

                if let selectedSource {
                    await loadHierarchy(for: selectedSource)
                }
            } catch {
                if Task.isCancelled { return }
                state = .failed(error.localizedDescription)
            }
        }

        private func loadHierarchy(for source: Model.Source) async {
            do {
                let items = try await backend.listSourceHierarchy(source: source, level: 1, parent: nil)
                if Task.isCancelled { return }
                hierarchyItems = items
            } catch {
                NSLog("Failed to load hierarchy: \(error)")
            }
        }

        public func listSources() async throws -> [Model.Source] {
            try await backend.listSources()
        }

        // MARK: Selected-document reading (the detail column)

        public typealias DocumentState = Presentation.FrameworkBrowser.DocumentState

        public internal(set) var documentState: DocumentState = .empty

        public private(set) var selectedSource: Model.Source?
        public private(set) var selectedFrameworkID: String?
        public var searchQuery: String = ""
        public var sortOrder: Presentation.FrameworkBrowser.SortOrder = .count

        public func selectSource(_ source: Model.Source?) {
            if source == selectedSource { return }
            selectedSource = source
            searchQuery = ""
            selectFramework(nil)

            hierarchyTask?.cancel()
            hierarchyItems = []

            guard let source else { return }

            if didConnect {
                hierarchyTask = Task { [weak self] in
                    guard let self else { return }
                    await loadHierarchy(for: source)
                }
            }
        }

        public internal(set) var documents: [Model.DocHit] = []

        var docTask: Task<Void, Never>?

        /// Load a document for the selected framework, or clear when nothing is
        /// selected. The shells call this when the sidebar selection changes, so the
        /// detail column shows real document content rather than just the id.
        public func selectFramework(_ id: String?) {
            if id == selectedFrameworkID { return }
            selectedFrameworkID = id
            let previous = docTask
            previous?.cancel()
            guard let id else {
                docTask = nil
                documents = []
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
                await self?.loadDocuments(framework: id)
            }
        }
    }
}

// MARK: - UI bindings computed properties

public extension Feature.FrameworkBrowser.ViewModel {
    var isLoading: Bool {
        if case .loading = state { true } else { false }
    }

    var errorMessage: String? {
        if case let .failed(message) = state { message } else { nil }
    }

    var connectionState: ConnectionState {
        switch state {
        case .idle, .loading: .connecting
        case .loaded: .connected
        case .failed: .failed
        }
    }

    var selectedMarkdown: String? {
        if case let .loaded(page) = documentState { page.markdown } else { nil }
    }

    var selectedDocumentTitle: String? {
        if case let .loaded(page) = documentState { page.title } else { nil }
    }

    var isLoadingDocument: Bool {
        if case .loading = documentState { true } else { false }
    }

    var documentError: String? {
        if case let .failed(message) = documentState { message } else { nil }
    }

    var selectedFramework: Model.Framework? {
        guard let selectedFrameworkID else { return nil }
        return frameworks.first(where: { $0.id == selectedFrameworkID })
    }
}
