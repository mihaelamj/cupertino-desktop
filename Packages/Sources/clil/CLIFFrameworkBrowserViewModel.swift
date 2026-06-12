import AppModels
import Foundation
import PresentationBridge

@MainActor
final class CLIFFrameworkBrowserViewModel: Presentation.FrameworkBrowserViewModelProtocol {
    var state: Presentation.FrameworkBrowser.LoadState = .idle
    var frameworks: [Model.Framework] = []
    var sources: [Model.Source] {
        Model.Source.allCases
    }

    var isLoading: Bool = false
    var errorMessage: String?
    var connectionState: Presentation.FrameworkBrowser.ConnectionState = .connecting
    var documentState: Presentation.FrameworkBrowser.DocumentState = .empty
    var selectedMarkdown: String?
    var selectedDocumentTitle: String?
    var selectedFramework: Model.Framework?
    var documents: [Model.DocHit] = []
    var isLoadingDocument: Bool = false
    var documentError: String?
    var selectedSource: Model.Source?
    var searchQuery: String = ""
    var sortOrder: Presentation.FrameworkBrowser.SortOrder = .count

    func onAppeared() {}
    func onRetried() {}
    func listSources() async throws -> [Model.Source] {
        Model.Source.allCases
    }

    func selectSource(_ source: Model.Source?) {
        selectedSource = source
    }

    func selectFramework(_ id: String?) {
        if let id {
            selectedFramework = Model.Framework(id: id, name: id.capitalized, documentCount: 5)
        } else {
            selectedFramework = nil
        }
    }

    func selectDocument(_ uri: Model.DocURI) {
        documentState = .loading
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 20_000_000)
            documentState = .loaded(Model.DocPage(uri: uri, source: .appleDocs, title: "MockDoc", markdown: "# MockDoc"))
        }
    }

    func openDocument(_ uri: Model.DocURI) {
        documentState = .loading
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 20_000_000)
            documentState = .loaded(Model.DocPage(uri: uri, source: .appleDocs, title: "MockDocOpen", markdown: "# MockDocOpen"))
        }
    }

    func readPage(_ uri: Model.DocURI) async throws -> Model.DocPage {
        Model.DocPage(uri: uri, source: .appleDocs, title: "MockDoc", markdown: "# MockDoc")
    }
}
