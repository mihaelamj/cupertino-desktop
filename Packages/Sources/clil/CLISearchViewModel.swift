import AppModels
import Foundation
import PresentationBridge

@MainActor
final class CLISearchViewModel: Presentation.SearchViewModelProtocol {
    var scope: Presentation.Search.Scope = .docs
    var text: String = ""
    var sources: Set<Model.Source> = [.appleDocs]
    var framework: String = ""
    var minIOS: String = ""
    var minMacOS: String = ""
    var minSwift: String = ""
    var limit: Int = 20
    var state: Presentation.Search.State = .idle
    var results: [Model.DocHit] = []
    var docsTree: [Presentation.SearchResultNode] = []
    var unified: Model.UnifiedResults?
    var isLoading: Bool = false
    var errorMessage: String?
    var hasRun: Bool = false

    func toggle(_ source: Model.Source) {
        if sources.contains(source) {
            sources.remove(source)
        } else {
            sources.insert(source)
        }
    }

    func run() {
        hasRun = true
        isLoading = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 20_000_000)
            isLoading = false
            let docs = [
                Model.DocHit(
                    id: "swift-basics",
                    uri: Model.DocURI("apple-docs://swift/basics")!,
                    source: .appleDocs,
                    title: "Swift Basics",
                    framework: "Swift",
                    snippet: "Learn Swift basics",
                    score: 1.0,
                ),
                Model.DocHit(
                    id: "swift-advanced",
                    uri: Model.DocURI("apple-docs://swift/advanced")!,
                    source: .appleDocs,
                    title: "Advanced Swift",
                    framework: "Swift",
                    snippet: "Learn advanced Swift",
                    score: 0.9,
                ),
            ]
            results = docs
            state = .loaded(.docs(docs))
        }
    }

    func runDebounced() {
        hasRun = true
        isLoading = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 20_000_000)
            isLoading = false
            let docs = [
                Model.DocHit(
                    id: "swift-basics",
                    uri: Model.DocURI("apple-docs://swift/basics")!,
                    source: .appleDocs,
                    title: "Swift Basics",
                    framework: "Swift",
                    snippet: "Learn Swift basics",
                    score: 1.0,
                ),
                Model.DocHit(
                    id: "swift-advanced",
                    uri: Model.DocURI("apple-docs://swift/advanced")!,
                    source: .appleDocs,
                    title: "Advanced Swift",
                    framework: "Swift",
                    snippet: "Learn advanced Swift",
                    score: 0.9,
                ),
            ]
            results = docs
            state = .loaded(.docs(docs))
        }
    }

    func readPage(_ uri: Model.DocURI) async throws -> Model.DocPage {
        Model.DocPage(uri: uri, source: .appleDocs, title: "MockDoc", markdown: "# MockDoc")
    }
}
