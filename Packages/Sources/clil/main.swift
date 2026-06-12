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

@main
struct CLILRunner {
    static func main() async {
        let args = CommandLine.arguments
        guard args.count > 1 else {
            print("Usage: swift run clil <file.clil | file.cdsl | file.cll>")
            exit(1)
        }

        let filePath = args[1]
        let fileURL = URL(fileURLWithPath: filePath)

        do {
            let script = try String(contentsOf: fileURL, encoding: .utf8)
            let frameworksVM = CLIFFrameworkBrowserViewModel()
            let searchVM = CLISearchViewModel()
            let simulator = Presentation.CLILSimulator(frameworks: frameworksVM, search: searchVM)

            print("Running CLIL simulation script '\(filePath)'...")

            if filePath.hasSuffix(".cdsl") {
                try await simulator.runCDSL(script)
            } else if filePath.hasSuffix(".cll") {
                try await simulator.runCLL(script)
            } else {
                try await simulator.run(script)
            }

            print("\u{001B}[32mSUCCESS: All assertions passed successfully!\u{001B}[0m")
        } catch {
            print("\u{001B}[31mFAILURE: \(error)\u{001B}[0m")
            exit(1)
        }
    }
}
