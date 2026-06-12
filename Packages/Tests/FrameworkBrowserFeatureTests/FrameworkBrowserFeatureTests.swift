import AppCore
import AppModels
import BackendAPI
@testable import FrameworkBrowserFeature
import Testing

@Suite("FrameworkBrowser.ViewModel")
@MainActor
struct FrameworkBrowserViewModelTests {
    @Test("starts idle with no frameworks")
    func startsIdle() {
        let viewModel = Feature.FrameworkBrowser.ViewModel(backend: FakeBackend(.success([])))
        if case .idle = viewModel.state {} else { Issue.record("expected .idle, got \(viewModel.state)") }
        #expect(viewModel.frameworks.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("a successful load connects, then surfaces the frameworks")
    func loadsFrameworks() async {
        let backend = FakeBackend(.success([
            Model.Framework(id: "swiftui", name: "swiftui", documentCount: 8679),
            Model.Framework(id: "foundation", name: "foundation", documentCount: 13649),
        ]))
        let viewModel = Feature.FrameworkBrowser.ViewModel(backend: backend)

        await viewModel.load()

        #expect(await backend.didConnect)
        #expect(viewModel.frameworks.map(\.id) == ["foundation", "swiftui"])
        #expect(viewModel.frameworks.first?.documentCount == 13649)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("a backend failure surfaces an error message and no frameworks")
    func loadFailure() async {
        let viewModel = Feature.FrameworkBrowser.ViewModel(backend: FakeBackend(.fail))

        await viewModel.load()

        #expect(viewModel.frameworks.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }

    @Test("retry clears a failure and reloads successfully")
    func retryAfterFailure() async {
        let backend = FakeBackend(.failOnceThenOK([
            Model.Framework(id: "swiftui", name: "swiftui", documentCount: 1),
        ]))
        let viewModel = Feature.FrameworkBrowser.ViewModel(backend: backend)

        await viewModel.load()
        #expect(viewModel.errorMessage != nil)

        await viewModel.load()
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.frameworks.map(\.id) == ["swiftui"])
    }

    @Test("selecting a framework loads its list of documents, then selecting a document loads its content")
    func documentLoads() async {
        let viewModel = Feature.FrameworkBrowser.ViewModel(backend: FakeBackend(.success([])))
        await viewModel.loadDocuments(framework: "swiftui")
        #expect(viewModel.documents.count == 1)
        #expect(viewModel.documents.first?.title == "View")

        if let uri = viewModel.documents.first?.uri {
            await viewModel.readDocument(uri)
            #expect(viewModel.selectedMarkdown == "# Doc")
            #expect(viewModel.selectedDocumentTitle == "Doc")
        } else {
            Issue.record("Expected a document URI")
        }
    }

    @Test("deselecting clears the document")
    func deselectClearsDocument() {
        let viewModel = Feature.FrameworkBrowser.ViewModel(backend: FakeBackend(.success([])))
        viewModel.selectFramework(nil)
        #expect(viewModel.selectedMarkdown == nil)
    }

    @Test("rapid framework switching serializes loads: no overlapping backend reads, latest wins")
    func rapidSwitchingSerializes() async {
        // Walking the list while a page loads used to fire overlapping reads on the one shared
        // subprocess client and race (an intermittent crash). The view model now waits for the
        // in-flight load before starting the next, so reads never overlap.
        let backend = ConcurrencyProbeBackend()
        let viewModel = Feature.FrameworkBrowser.ViewModel(backend: backend)

        viewModel.selectFramework("alpha")
        await Task.yield() // let the first load reach the backend and suspend mid-read
        viewModel.selectFramework("beta")
        await Task.yield()
        viewModel.selectFramework("gamma")
        await viewModel.awaitDocumentLoad()

        #expect(await backend.maxConcurrent == 1) // the barrier prevents overlapping reads
        #expect(viewModel.documents.first?.title == "gamma") // the latest selection wins
    }

    @Test("belongs(framework:to:) classifies frameworks correctly across all 8 sources")
    func belongsToSource() {
        // Doc-like sources and their expected frameworks
        let swiftUI = Model.Framework(id: "swiftui", name: "SwiftUI", documentCount: 100)
        let foundation = Model.Framework(id: "foundation", name: "Foundation", documentCount: 50)
        let appKit = Model.Framework(id: "appkit", name: "AppKit", documentCount: 20)

        // appleDocs contains swiftui, foundation, but NOT archive-only/non-apple docs
        #expect(Feature.FrameworkBrowser.ViewModel.belongs(framework: swiftUI, to: .appleDocs) == true)
        #expect(Feature.FrameworkBrowser.ViewModel.belongs(framework: foundation, to: .appleDocs) == true)
        #expect(Feature.FrameworkBrowser.ViewModel.belongs(framework: appKit, to: .appleDocs) == false) // appkit belongs to appleArchive

        // appleArchive contains appkit, cocoa, coregraphics etc.
        #expect(Feature.FrameworkBrowser.ViewModel.belongs(framework: appKit, to: .appleArchive) == true)
        #expect(Feature.FrameworkBrowser.ViewModel.belongs(framework: swiftUI, to: .appleArchive) == false)

        // hig contains foundations, components, general, inputs, patterns, technologies
        let foundations = Model.Framework(id: "foundations", name: "Foundations", documentCount: 5)
        #expect(Feature.FrameworkBrowser.ViewModel.belongs(framework: foundations, to: .hig) == true)
        #expect(Feature.FrameworkBrowser.ViewModel.belongs(framework: swiftUI, to: .hig) == false)

        // swiftEvolution contains swift-evolution
        let swiftEvolution = Model.Framework(id: "swift-evolution", name: "Swift Evolution", documentCount: 200)
        #expect(Feature.FrameworkBrowser.ViewModel.belongs(framework: swiftEvolution, to: .swiftEvolution) == true)

        // swiftOrg contains swift-org
        let swiftOrg = Model.Framework(id: "swift-org", name: "Swift.org", documentCount: 50)
        #expect(Feature.FrameworkBrowser.ViewModel.belongs(framework: swiftOrg, to: .swiftOrg) == true)

        // swiftBook contains swift-book
        let swiftBook = Model.Framework(id: "swift-book", name: "Swift Book", documentCount: 30)
        #expect(Feature.FrameworkBrowser.ViewModel.belongs(framework: swiftBook, to: .swiftBook) == true)

        // samples contains samples
        let samples = Model.Framework(id: "samples", name: "Samples", documentCount: 10)
        #expect(Feature.FrameworkBrowser.ViewModel.belongs(framework: samples, to: .samples) == true)

        // packages contains packages
        let packages = Model.Framework(id: "packages", name: "Packages", documentCount: 15)
        #expect(Feature.FrameworkBrowser.ViewModel.belongs(framework: packages, to: .packages) == true)
    }

    @Test("filtering frameworks by selected source correctly filters list")
    func selectedSourceFiltersFrameworks() async {
        let allFrameworks = [
            Model.Framework(id: "swiftui", name: "SwiftUI", documentCount: 10),
            Model.Framework(id: "appkit", name: "AppKit", documentCount: 5),
            Model.Framework(id: "samples", name: "Samples", documentCount: 1),
            Model.Framework(id: "packages", name: "Packages", documentCount: 2),
        ]
        let backend = FakeBackend(.success(allFrameworks))
        let viewModel = Feature.FrameworkBrowser.ViewModel(backend: backend)
        await viewModel.load()

        // Default with no selected source shows all
        #expect(viewModel.frameworks.count == 4)

        // Selecting appleDocs filters to SwiftUI
        viewModel.selectSource(.appleDocs)
        #expect(viewModel.frameworks.map(\.id) == ["swiftui"])

        // Selecting appleArchive filters to AppKit
        viewModel.selectSource(.appleArchive)
        #expect(viewModel.frameworks.map(\.id) == ["appkit"])

        // Selecting samples filters to samples
        viewModel.selectSource(.samples)
        #expect(viewModel.frameworks.map(\.id) == ["samples"])

        // Selecting packages filters to packages
        viewModel.selectSource(.packages)
        #expect(viewModel.frameworks.map(\.id) == ["packages"])
    }
}

/// Records the peak number of overlapping document reads, to prove the view model serializes
/// loads. `searchDocs` suspends briefly (cooperative yields) so any overlap is observable, and
/// encodes the queried framework into the result so the test can assert which load won.
private actor ConcurrencyProbeBackend: Backend.Connecting, Backend.FrameworkBrowsing, Backend.Searching, Backend.DocumentReading {
    private var inFlight = 0
    private(set) var maxConcurrent = 0

    func connect() async throws {}
    func disconnect() async {}

    func searchDocs(_ query: Model.DocsQuery) async throws -> [Model.DocHit] {
        inFlight += 1
        maxConcurrent = max(maxConcurrent, inFlight)
        for _ in 0 ..< 3 {
            await Task.yield()
        }
        inFlight -= 1
        let framework = query.framework ?? "x"
        guard let uri = Model.DocURI("apple-docs://\(framework)") else { return [] }
        return [Model.DocHit(id: "1", uri: uri, source: .appleDocs, title: framework, framework: framework, snippet: "", score: 1)]
    }

    func readDocument(_ uri: Model.DocURI) async throws -> Model.DocPage {
        let title = uri.rawValue.replacingOccurrences(of: "apple-docs://", with: "")
        return Model.DocPage(uri: uri, source: .appleDocs, title: title, markdown: "# \(title)")
    }

    func searchSamples(_: Model.SampleQuery) async throws -> Model.SampleResults {
        throw Boom.boom
    }

    func searchPackages(_: Model.PackageQuery) async throws -> [Model.PackageHit] {
        throw Boom.boom
    }

    func searchEverything(_: Model.UnifiedQuery) async throws -> Model.UnifiedResults {
        throw Boom.boom
    }

    func listFrameworks() async throws -> [Model.Framework] {
        []
    }

    func listSources() async throws -> [Model.Source] {
        Model.Source.allCases
    }

    func listSourceHierarchy(source _: Model.Source, level: Int, parent _: String?) async throws -> [Model.HierarchyItem] {
        if level == 1 {
            [Model.HierarchyItem(id: "swiftui", title: "SwiftUI", hasChildren: true)]
        } else {
            [Model.HierarchyItem(id: "apple-docs://swiftui/view", title: "View", hasChildren: false)]
        }
    }

    enum Boom: Error { case boom }
}

/// A minimal `Backend.Connecting & Backend.FrameworkBrowsing` double. Possible only
/// because the view model depends on the narrow slices, not the full backend.
private actor FakeBackend: Backend.Connecting, Backend.FrameworkBrowsing, Backend.Searching, Backend.DocumentReading {
    enum Mode {
        case success([Model.Framework])
        case fail
        case failOnceThenOK([Model.Framework])
    }

    private var mode: Mode
    private(set) var didConnect = false

    init(_ mode: Mode) {
        self.mode = mode
    }

    func connect() async throws {
        didConnect = true
    }

    func disconnect() async {}

    func readDocument(_ uri: Model.DocURI) async throws -> Model.DocPage {
        Model.DocPage(uri: uri, source: .appleDocs, title: "Doc", markdown: "# Doc")
    }

    func searchDocs(_: Model.DocsQuery) async throws -> [Model.DocHit] {
        guard let uri = Model.DocURI("apple-docs://swiftui/view") else { return [] }
        return [Model.DocHit(id: "1", uri: uri, source: .appleDocs, title: "View", framework: "swiftui", snippet: "", score: 1)]
    }

    func searchSamples(_: Model.SampleQuery) async throws -> Model.SampleResults {
        throw Failure.boom
    }

    func searchPackages(_: Model.PackageQuery) async throws -> [Model.PackageHit] {
        throw Failure.boom
    }

    func searchEverything(_: Model.UnifiedQuery) async throws -> Model.UnifiedResults {
        throw Failure.boom
    }

    func listFrameworks() async throws -> [Model.Framework] {
        switch mode {
        case let .success(frameworks):
            return frameworks
        case .fail:
            throw Failure.boom
        case let .failOnceThenOK(frameworks):
            mode = .success(frameworks)
            throw Failure.boom
        }
    }

    func listSources() async throws -> [Model.Source] {
        switch mode {
        case .fail:
            throw Failure.boom
        default:
            return Model.Source.allCases
        }
    }

    func listSourceHierarchy(source _: Model.Source, level: Int, parent _: String?) async throws -> [Model.HierarchyItem] {
        switch mode {
        case .fail:
            throw Failure.boom
        default:
            if level == 1 {
                return [Model.HierarchyItem(id: "swiftui", title: "SwiftUI", hasChildren: true)]
            } else {
                return [Model.HierarchyItem(id: "apple-docs://swiftui/view", title: "View", hasChildren: false)]
            }
        }
    }

    enum Failure: Error { case boom }
}
