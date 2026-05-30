import AppCore
import AppModels
import BackendAPI
@testable import SearchFeature
import Testing

@Suite("Search.ViewModel")
@MainActor
struct SearchViewModelTests {
    @Test("a search loads hits into the state")
    func loadsHits() async {
        let viewModel = Feature.Search.ViewModel(backend: FakeSearch())
        await viewModel.load(Model.DocsQuery(text: "view"))
        #expect(viewModel.results.count == 1)
        #expect(viewModel.results.first?.title == "View")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("a backend failure surfaces an error and no results")
    func failureSurfaces() async {
        let viewModel = Feature.Search.ViewModel(backend: FakeSearch(fail: true))
        await viewModel.load(Model.DocsQuery(text: "x"))
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.results.isEmpty)
    }

    @Test("toggling a source adds and removes it from the query set")
    func toggleSource() {
        let viewModel = Feature.Search.ViewModel(backend: FakeSearch())
        viewModel.toggle(Model.Source.hig)
        #expect(viewModel.sources.contains(Model.Source.hig))
        viewModel.toggle(Model.Source.appleDocs)
        #expect(!viewModel.sources.contains(Model.Source.appleDocs))
    }
}

/// A fake `Backend.Searching`: the view model depends only on that slice, so the test
/// needs no transport and no corpus.
private struct FakeSearch: Backend.Searching {
    var fail = false

    enum Boom: Error { case boom }

    func searchDocs(_: Model.DocsQuery) async throws -> [Model.DocHit] {
        if fail { throw Boom.boom }
        guard let uri = Model.DocURI("apple-docs://swiftui/view") else { return [] }
        return [Model.DocHit(id: "1", uri: uri, source: .appleDocs, title: "View", framework: "SwiftUI", snippet: "", score: 1)]
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
}
