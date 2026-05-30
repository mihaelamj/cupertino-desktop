import AppModels
import BackendAPI
import CupertinoDataKit
import Foundation
@testable import LocalEmbeddedBackend
import Testing

@Suite("LocalEmbedded adapter (over CupertinoDataKit.Search.DocumentReading)")
struct LocalEmbeddedBackendTests {
    // MARK: Pure mapping (the adapter's translation)

    @Test("listFrameworks maps name->count and orders by count desc, then name")
    func frameworksMapping() {
        let mapped = Backend.LocalEmbedded.frameworks(from: ["uikit": 12, "swiftui": 12, "foundation": 99])
        #expect(mapped.map(\.id) == ["foundation", "swiftui", "uikit"]) // 99 first; tie broken by name
        #expect(mapped.first?.documentCount == 99)
        #expect(mapped.allSatisfy { $0.id == $0.name }) // id is the framework name
    }

    @Test("title is taken from the first markdown heading, else nil")
    func titleExtraction() {
        #expect(Backend.LocalEmbedded.title(fromMarkdown: "intro\n# SwiftUI\nbody") == "SwiftUI")
        #expect(Backend.LocalEmbedded.title(fromMarkdown: "no heading here") == nil)
    }

    @Test("a Search.Result maps to a DocHit; an invalid URI is dropped")
    func hitMapping() throws {
        let valid = Search.Result(
            uri: "apple-docs://swiftui/view",
            source: "apple-docs",
            framework: "swiftui",
            title: "View",
            summary: "A view.",
            filePath: "",
            wordCount: 3,
            rank: -2.0,
        )
        let hit = try #require(Backend.LocalEmbedded.hit(from: valid))
        #expect(hit.uri.rawValue == "apple-docs://swiftui/view")
        #expect(hit.framework == "swiftui")
        #expect(hit.score == 2.0) // score = -rank
        let bad = Search.Result(uri: "not a uri", source: "apple-docs", framework: "", title: "x", summary: "", filePath: "", wordCount: 0, rank: 0)
        #expect(Backend.LocalEmbedded.hit(from: bad) == nil)
    }

    // MARK: Adapter over the injected strategy

    @Test("listFrameworks reads through the data source")
    func listFrameworks() async throws {
        let backend = Backend.LocalEmbedded(dataSource: FakeDataSource(frameworks: ["swiftui": 8679, "uikit": 12416]))
        let frameworks = try await backend.listFrameworks()
        #expect(frameworks.map(\.id) == ["uikit", "swiftui"]) // count desc
    }

    @Test("readDocument returns a page for a present URI and throws notFound otherwise")
    func readDocument() async throws {
        let uri = try #require(Model.DocURI("apple-docs://swiftui/view"))
        let backend = Backend.LocalEmbedded(dataSource: FakeDataSource(documents: [uri.rawValue: "# View\nA view."]))

        let page = try await backend.readDocument(uri)
        #expect(page.title == "View")
        #expect(page.markdown.contains("A view."))
        #expect(page.source == .appleDocs)

        let missing = try #require(Model.DocURI("apple-docs://swiftui/missing"))
        await #expect(throws: Backend.Failure.self) {
            _ = try await backend.readDocument(missing)
        }
    }

    @Test("searchDocs maps the data source's results into DocHits")
    func searchDocs() async throws {
        let result = Search.Result(
            uri: "apple-docs://swiftui/view",
            source: "apple-docs",
            framework: "swiftui",
            title: "View",
            summary: "A view.",
            filePath: "",
            wordCount: 3,
            rank: -1.5,
        )
        let backend = Backend.LocalEmbedded(dataSource: FakeDataSource(results: [result]))
        let hits = try await backend.searchDocs(Model.DocsQuery(text: "view"))
        #expect(hits.count == 1)
        #expect(hits.first?.title == "View")
    }

    @Test("searchDocs over a multi-source subset keeps only the selected sources")
    func searchDocsFiltersToSelectedSources() async throws {
        let results = [
            docResult("apple-docs://swiftui/view", source: "apple-docs"),
            docResult("hig://components/button", source: "hig"),
            docResult("swift-evolution://0001", source: "swift-evolution"),
        ]
        let backend = Backend.LocalEmbedded(dataSource: FakeDataSource(results: results))
        let hits = try await backend.searchDocs(Model.DocsQuery(text: "x", sources: [.appleDocs, .hig]))
        #expect(hits.count == 2)
        #expect(Set(hits.map(\.source)) == Set([Model.Source.appleDocs, .hig])) // swift-evolution dropped
    }

    @Test("an unadopted slice (samples) fails honestly")
    func unsupportedVerb() async {
        let backend = Backend.LocalEmbedded(dataSource: FakeDataSource())
        await #expect(throws: Backend.Failure.self) {
            _ = try await backend.listSamples(framework: nil, limit: 10)
        }
    }
}

/// A minimal `Search.Result` for the given URI and source, enough to map to a DocHit.
private func docResult(_ uri: String, source: String) -> Search.Result {
    Search.Result(uri: uri, source: source, framework: "", title: uri, summary: "", filePath: "", wordCount: 1, rank: -1)
}

/// A fake `Search.DocumentReading`: the adapter depends on the protocol, so the read
/// engine is replaced with canned data, no SQLite, no corpus.
private struct FakeDataSource: Search.DocumentReading {
    var frameworks: [String: Int] = [:]
    var documents: [String: String] = [:]
    var results: [Search.Result] = []

    // swiftlint:disable:next function_parameter_count
    func search(
        query _: String, source _: String?, framework _: String?, language _: String?,
        limit _: Int, includeArchive _: Bool,
        minIOS _: String?, minMacOS _: String?, minTvOS _: String?,
        minWatchOS _: String?, minVisionOS _: String?, minSwift _: String?,
    ) async throws -> [Search.Result] {
        results
    }

    func getDocumentContent(uri: String, format _: Search.DocumentFormat) async throws -> String? {
        documents[uri]
    }

    func listFrameworks() async throws -> [String: Int] {
        frameworks
    }

    func documentCount() async throws -> Int {
        documents.count
    }

    func disconnect() async {}
}
