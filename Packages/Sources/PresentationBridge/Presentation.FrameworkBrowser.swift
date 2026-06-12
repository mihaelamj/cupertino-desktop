import AppModels
import Foundation
import Observation

public extension Presentation {
    enum FrameworkBrowser {
        public typealias LoadState = Presentation.LoadState<[Model.Framework]>

        public enum ConnectionState: Sendable, Equatable {
            case connecting
            case connected
            case failed
        }

        public enum DocumentState: Sendable {
            case empty
            case loading
            case loaded(Model.DocPage)
            case failed(String)
        }

        public enum SortOrder: String, Sendable, CaseIterable {
            case count
            case name
        }
    }

    @MainActor
    protocol DocumentPageReader: AnyObject {
        func readPage(_ uri: Model.DocURI) async throws -> Model.DocPage
    }

    /// The contract for the framework browser view model, isolating the UI shells from the concrete feature packages.
    @MainActor
    protocol FrameworkBrowserViewModelProtocol: AnyObject, Observable, DocumentPageReader {
        var state: Presentation.FrameworkBrowser.LoadState { get }
        var frameworks: [Model.Framework] { get }
        var isLoading: Bool { get }
        var errorMessage: String? { get }
        var connectionState: Presentation.FrameworkBrowser.ConnectionState { get }
        var documentState: Presentation.FrameworkBrowser.DocumentState { get }
        var selectedMarkdown: String? { get }
        var selectedDocumentTitle: String? { get }
        var selectedFramework: Model.Framework? { get }
        var documents: [Model.DocHit] { get }
        var isLoadingDocument: Bool { get }
        var documentError: String? { get }

        var selectedSource: Model.Source? { get }
        var searchQuery: String { get set }
        var sortOrder: Presentation.FrameworkBrowser.SortOrder { get set }

        func onAppeared()
        func onRetried()
        func selectSource(_ source: Model.Source?)
        func selectFramework(_ id: String?)
        func selectDocument(_ uri: Model.DocURI)
        func openDocument(_ uri: Model.DocURI)
    }
}
