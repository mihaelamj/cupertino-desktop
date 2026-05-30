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
        []
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
