import AppModels
import PresentationBridge
import Testing

@Suite("PresentationBridge")
struct PresentationBridgeTests {
    @Test("load state carries loaded values and failed messages")
    func loadState() {
        let loaded = Presentation.LoadState<[String]>.loaded(["SwiftUI"])
        let failed = Presentation.LoadState<[String]>.failed("missing corpus")

        if case let .loaded(values) = loaded {
            #expect(values == ["SwiftUI"])
        } else {
            Issue.record("expected loaded state")
        }

        if case let .failed(message) = failed {
            #expect(message == "missing corpus")
        } else {
            Issue.record("expected failed state")
        }
    }

    @Test("doc hits group by framework with stable leaf nodes")
    func groupsDocsByFramework() throws {
        let hits = try [
            hit("a", "apple-docs://swiftui/navigation", "swiftui", "Navigation"),
            hit("b", "apple-docs://pdfkit/pdfview", "pdfkit", "PDFView"),
            hit("c", "apple-docs://swiftui/view", "swiftui", "View"),
        ]

        let tree = Presentation.SearchResultTree.make(docs: hits)

        #expect(tree.map(\.title) == ["SwiftUI", "PDFKit"])
        #expect(tree[0].children.map(\.id) == ["a", "c"])
        #expect(tree[0].isLeaf == false)
        #expect(tree[0].children[0].isLeaf)
        #expect(tree[0].children[0].uri?.rawValue == "apple-docs://swiftui/navigation")
        #expect(tree[1].subtitle == "1")
    }

    @Test("missing framework groups under Other")
    func missingFrameworkGroupsUnderOther() throws {
        let tree = try Presentation.SearchResultTree.make(docs: [
            hit("a", "apple-docs://documentation/root", nil, "Root"),
        ])

        #expect(tree.count == 1)
        #expect(tree[0].id == "framework:other")
        #expect(tree[0].title == "Other")
    }

    private func hit(_ id: String, _ uri: String, _ framework: String?, _ title: String) throws -> Model.DocHit {
        try Model.DocHit(
            id: id,
            uri: #require(Model.DocURI(uri)),
            source: .appleDocs,
            title: title,
            framework: framework,
            snippet: "",
            score: 1,
        )
    }
}

// MARK: - Mocks for Testing CLILSimulator

@MainActor
final class MockFrameworkBrowserViewModel: Presentation.FrameworkBrowserViewModelProtocol {
    var state: Presentation.FrameworkBrowser.LoadState = .idle
    var frameworks: [Model.Framework] = []
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

    var onAppearedCalled = false
    func onAppeared() {
        onAppearedCalled = true
    }

    var onRetriedCalled = false
    func onRetried() {
        onRetriedCalled = true
    }

    var selectedSourcePassed: Model.Source?
    func selectSource(_ source: Model.Source?) {
        selectedSourcePassed = source
        selectedSource = source
    }

    var selectedFrameworkPassed: String?
    func selectFramework(_ id: String?) {
        selectedFrameworkPassed = id
        if let id {
            selectedFramework = Model.Framework(id: id, name: id, documentCount: 5)
        } else {
            selectedFramework = nil
        }
    }

    var selectedDocumentPassed: Model.DocURI?
    func selectDocument(_ uri: Model.DocURI) {
        selectedDocumentPassed = uri
        documentState = .loaded(Model.DocPage(uri: uri, source: .appleDocs, title: "MockDoc", markdown: "# MockDoc"))
    }

    var openDocumentPassed: Model.DocURI?
    func openDocument(_ uri: Model.DocURI) {
        openDocumentPassed = uri
        documentState = .loaded(Model.DocPage(uri: uri, source: .appleDocs, title: "MockDocOpen", markdown: "# MockDocOpen"))
    }

    func readPage(_ uri: Model.DocURI) async throws -> Model.DocPage {
        Model.DocPage(uri: uri, source: .appleDocs, title: "MockDoc", markdown: "# MockDoc")
    }
}

@MainActor
final class MockSearchViewModel: Presentation.SearchViewModelProtocol {
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

    var runCalled = false
    func run() {
        runCalled = true
        hasRun = true
    }

    var runDebouncedCalled = false
    func runDebounced() {
        runDebouncedCalled = true
        hasRun = true
    }

    func readPage(_ uri: Model.DocURI) async throws -> Model.DocPage {
        Model.DocPage(uri: uri, source: .appleDocs, title: "MockDoc", markdown: "# MockDoc")
    }
}

// MARK: - CLILSimulator Tests

@Suite("Presentation.CLILSimulator")
@MainActor
struct CLILSimulatorTests {
    @Test("parses and executes a valid device profile and updates UI states")
    func deviceStateUpdates() async throws {
        let frameworksVM = MockFrameworkBrowserViewModel()
        let searchVM = MockSearchViewModel()
        let simulator = Presentation.CLILSimulator(frameworks: frameworksVM, search: searchVM)

        #expect(simulator.ui.device == .Mac)
        #expect(simulator.ui.orientation == .landscape)
        #expect(simulator.ui.sizeClass == .regular)
        #expect(simulator.ui.showsSidebarList == true)
        #expect(simulator.ui.showsDetailPane == true)
        #expect(simulator.ui.navigationStackDepth == 0)

        try await simulator.run("""
        device iPhone in portrait with compact
        assert ui device == "iPhone"
        assert ui orientation == "portrait"
        assert ui sizeClass == "compact"
        assert ui showsSidebarList == true
        assert ui showsDetailPane == false
        assert ui navigationStackDepth == 0
        assert ui activeView == "Databases"
        """)
    }

    @Test("dispatches view model actions correctly")
    func actionDispatches() async throws {
        let frameworksVM = MockFrameworkBrowserViewModel()
        let searchVM = MockSearchViewModel()
        let simulator = Presentation.CLILSimulator(frameworks: frameworksVM, search: searchVM)

        try await simulator.run("""
        device iPhone in portrait with compact
        dispatch selectSource("apple-docs")
        assert vm activeSource == "appleDocs"
        assert ui navigationStackDepth == 1
        assert ui activeView == "Frameworks"

        dispatch selectFramework("swiftui")
        assert vm selectedFrameworkID == "swiftui"
        assert ui navigationStackDepth == 2
        assert ui activeView == "Documents"
        """)

        #expect(frameworksVM.selectedSourcePassed == .appleDocs)
        #expect(frameworksVM.selectedFrameworkPassed == "swiftui")
    }

    @Test("compiles and runs CDSL scripts successfully")
    func runCDSLScripts() async throws {
        let frameworksVM = MockFrameworkBrowserViewModel()
        let searchVM = MockSearchViewModel()
        let simulator = Presentation.CLILSimulator(frameworks: frameworksVM, search: searchVM)

        try await simulator.runCDSL("""
        dispatch selectSource("apple-docs")
        assert vm activeSource == "appleDocs"
        dispatch selectFramework("swiftui")
        assert vm selectedFrameworkID == "swiftui"
        await tasks
        """)

        #expect(frameworksVM.selectedSourcePassed == .appleDocs)
        #expect(frameworksVM.selectedFrameworkPassed == "swiftui")
    }

    @Test("compiles and runs CLL scripts successfully")
    func runCLLScripts() async throws {
        let frameworksVM = MockFrameworkBrowserViewModel()
        let searchVM = MockSearchViewModel()
        let simulator = Presentation.CLILSimulator(frameworks: frameworksVM, search: searchVM)

        try await simulator.runCLL("""
        device iPhone in portrait with compact
        assert ui device == "iPhone"
        assert ui orientation == "portrait"
        assert ui sizeClass == "compact"
        assert ui showsSidebarList == true
        assert ui showsDetailPane == false
        """)

        #expect(simulator.ui.device == .iPhone)
        #expect(simulator.ui.orientation == .portrait)
    }

    @Test("lexical and syntax errors throw correct error cases")
    func parsingErrors() async {
        let simulator = Presentation.CLILSimulator()

        await #expect(performing: {
            try await simulator.run("device iPhone in portrait with compact @")
        }, throws: { error in
            guard let cliErr = error as? Presentation.CLILError,
                  case let .lexicalError(msg) = cliErr else { return false }
            return msg.contains("Unexpected character '@'")
        })

        await #expect(performing: {
            try await simulator.run("device iPhone in portrait with")
        }, throws: { error in
            guard let cliErr = error as? Presentation.CLILError,
                  case let .syntaxError(msg) = cliErr else { return false }
            return msg.contains("Expected")
        })
    }
}
