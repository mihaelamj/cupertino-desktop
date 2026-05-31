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

    @Test("the everything scope loads unified results")
    func everythingScope() async {
        let viewModel = Feature.Search.ViewModel(backend: FakeSearch())
        await viewModel.loadEverything(Model.UnifiedQuery(text: "view"))
        #expect(viewModel.unified?.docs.count == 1)
    }

    @Test("doc hits group into a framework tree with canonical titles, preserving order")
    func groupsDocsIntoFrameworkTree() throws {
        func hit(_ id: String, _ uri: String, _ framework: String) throws -> Model.DocHit {
            try Model.DocHit(id: id, uri: #require(Model.DocURI(uri)), source: .appleDocs, title: id, framework: framework, snippet: "", score: 1)
        }
        let hits = try [
            hit("a", "apple-docs://swiftui/navigation", "swiftui"),
            hit("b", "apple-docs://pdfkit/navigation", "pdfkit"),
            hit("c", "apple-docs://swiftui/navigationbaritem", "swiftui"),
        ]
        let tree = Feature.Search.resultTree(docs: hits)
        #expect(tree.count == 2) // swiftui, pdfkit, first-seen order
        #expect(tree[0].title == "SwiftUI") // canonical display name
        #expect(tree[0].children.count == 2) // both swiftui hits under it
        #expect(tree[0].children.map(\.id) == ["a", "c"]) // search order preserved
        #expect(tree[0].uri == nil) // group node
        #expect(tree[0].children[0].uri?.rawValue == "apple-docs://swiftui/navigation") // leaf opens
        #expect(tree[1].title == "PDFKit")
    }
}

/// A fake `Backend.Searching`: the view model depends only on that slice, so the test
/// needs no transport and no corpus.
private struct FakeSearch: Backend.Searching, Backend.DocumentReading {
    var fail = false

    enum Boom: Error { case boom }

    func searchDocs(_: Model.DocsQuery) async throws -> [Model.DocHit] {
        if fail { throw Boom.boom }
        guard let uri = Model.DocURI("apple-docs://swiftui/view") else { return [] }
        return [Model.DocHit(id: "1", uri: uri, source: .appleDocs, title: "View", framework: "SwiftUI", snippet: "", score: 1)]
    }

    func readDocument(_ uri: Model.DocURI) async throws -> Model.DocPage {
        Model.DocPage(uri: uri, source: .appleDocs, title: "View", markdown: "# View")
    }

    func searchSamples(_: Model.SampleQuery) async throws -> Model.SampleResults {
        throw Boom.boom
    }

    func searchPackages(_: Model.PackageQuery) async throws -> [Model.PackageHit] {
        throw Boom.boom
    }

    func searchEverything(_: Model.UnifiedQuery) async throws -> Model.UnifiedResults {
        if fail { throw Boom.boom }
        let docs = try await searchDocs(Model.DocsQuery(text: ""))
        return Model.UnifiedResults(docs: docs, samples: Model.SampleResults(projects: [], files: []), packages: [])
    }
}
