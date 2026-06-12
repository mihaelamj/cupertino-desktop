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

        public var frameworks: [Model.Framework] {
            guard case let .loaded(all) = state else { return [] }
            
            var allWithPlaceholders = all
            if let selectedSource {
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
                    if ViewModel.belongs(framework: placeholder, to: selectedSource),
                       !allWithPlaceholders.contains(where: { $0.id == placeholder.id }) {
                        allWithPlaceholders.append(placeholder)
                    }
                }
            }
            
            let filteredBySource = selectedSource.map { source in
                allWithPlaceholders.filter { ViewModel.belongs(framework: $0, to: source) }
            } ?? all

            let filteredBySearch: [Model.Framework]
            if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                filteredBySearch = filteredBySource
            } else {
                let query = searchQuery.lowercased()
                filteredBySearch = filteredBySource.filter {
                    $0.displayName.lowercased().contains(query) || $0.id.lowercased().contains(query)
                }
            }

            switch sortOrder {
            case .count:
                return filteredBySearch.sorted {
                    $0.documentCount != $1.documentCount
                        ? $0.documentCount > $1.documentCount
                        : $0.name < $1.name
                }
            case .name:
                return filteredBySearch.sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
            }
        }

        public var isLoading: Bool {
            if case .loading = state { true } else { false }
        }

        public var errorMessage: String? {
            if case let .failed(message) = state { message } else { nil }
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

        public typealias DocumentState = Presentation.FrameworkBrowser.DocumentState

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

        public private(set) var selectedSource: Model.Source?
        public private(set) var selectedFrameworkID: String?
        public var searchQuery: String = ""
        public var sortOrder: Presentation.FrameworkBrowser.SortOrder = .count

        public func selectSource(_ source: Model.Source?) {
            if source == selectedSource { return }
            selectedSource = source
            searchQuery = ""
            selectFramework(nil)
        }

        public var selectedFramework: Model.Framework? {
            guard let selectedFrameworkID else { return nil }
            return frameworks.first(where: { $0.id == selectedFrameworkID })
        }

        public private(set) var documents: [Model.DocHit] = []

        public func selectDocument(_ uri: Model.DocURI) {
            NSLog("VM SELECT DOCUMENT: \(uri.rawValue)")
            if case let .loaded(page) = documentState, page.uri == uri {
                NSLog("VM SELECT DOCUMENT: already loaded")
                return
            }
            let previous = docTask
            previous?.cancel()
            documentState = .loading
            docTask = Task { [weak self] in
                NSLog("VM SELECT DOCUMENT: task started")
                await previous?.value
                guard !Task.isCancelled else {
                    NSLog("VM SELECT DOCUMENT: task cancelled after previous value")
                    return
                }
                NSLog("VM SELECT DOCUMENT: calling readDocument")
                await self?.readDocument(uri)
            }
        }

        public func readPage(_ uri: Model.DocURI) async throws -> Model.DocPage {
            try await backend.readDocument(uri)
        }

        private var docTask: Task<Void, Never>?

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

        /// Open an arbitrary document by URI in the detail column, replacing the current
        /// one. Used when a link inside a rendered document is tapped (e.g. a "Mentioned
        /// in" entry), so the reader can follow it without going through the sidebar.
        public func openDocument(_ uri: Model.DocURI) {
            if case let .loaded(page) = documentState, page.uri == uri {
                return
            }
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
                NSLog("VM READ DOCUMENT: backend read start: \(uri.rawValue)")
                let page = try await backend.readDocument(uri)
                if Task.isCancelled {
                    NSLog("VM READ DOCUMENT: task cancelled after backend read")
                    return
                }
                NSLog("VM READ DOCUMENT: loaded successfully: \(page.title)")
                documentState = .loaded(page)
            } catch {
                if Task.isCancelled {
                    NSLog("VM READ DOCUMENT: task cancelled on error")
                    return
                }
                NSLog("VM READ DOCUMENT: failed: \(error.localizedDescription)")
                documentState = .failed(error.localizedDescription)
            }
        }

        /// Search and load all documents in the selected framework. Scoped to it.
        func loadDocuments(framework id: String) async {
            do {
                let sources = selectedSource.map { Set([$0]) } ?? Set([.appleDocs])
                let hits = try await backend.searchDocs(Model.DocsQuery(text: id, sources: sources, framework: id, limit: 100))
                if Task.isCancelled { return }
                documents = hits
                if let first = hits.first {
                    await readDocument(first.uri)
                } else {
                    documentState = .empty
                }
            } catch {
                if Task.isCancelled { return }
                documents = []
                documentState = .failed(error.localizedDescription)
            }
        }

        public static func belongs(framework: Model.Framework, to source: Model.Source) -> Bool {
            let id = framework.id.lowercased()
            switch source {
            case .appleDocs:
                let nonAppleDocs: Set = [
                    "swift-evolution", "swift-org", "swift-book",
                    "components", "foundations", "general", "inputs", "patterns", "technologies",
                    "cocoa", "objectivec", "appkit", "samples", "packages",
                ]
                return !nonAppleDocs.contains(id)
            case .appleArchive:
                let archiveFrameworks: Set = [
                    "appkit", "cocoa", "coreaudio", "coredata", "corefoundation", "coregraphics",
                    "coreimage", "coretext", "foundation", "objectivec", "performance",
                    "quartzcore", "security", "uikit",
                ]
                return archiveFrameworks.contains(id)
            case .hig:
                return ["components", "foundations", "general", "inputs", "patterns", "technologies"].contains(id)
            case .swiftEvolution:
                return id == "swift-evolution"
            case .swiftOrg:
                return id == "swift-org"
            case .swiftBook:
                return id == "swift-book"
            case .samples:
                return id == "samples"
            case .packages:
                return id == "packages"
            }
        }
    }
}
