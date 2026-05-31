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
        #expect(viewModel.frameworks.map(\.id) == ["swiftui", "foundation"])
        #expect(viewModel.frameworks.first?.documentCount == 8679)
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

    @Test("selecting a framework loads and exposes its document")
    func documentLoads() async {
        let viewModel = Feature.FrameworkBrowser.ViewModel(backend: FakeBackend(.success([])))
        await viewModel.loadDocument(framework: "swiftui")
        #expect(viewModel.selectedMarkdown == "# Doc")
        #expect(viewModel.selectedDocumentTitle == "Doc")
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
        #expect(viewModel.selectedDocumentTitle == "gamma") // the latest selection wins
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

    enum Failure: Error { case boom }
}
