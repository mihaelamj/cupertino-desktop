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

    @Test("searchEverything buckets results by source into docs, samples, and packages")
    func everythingBuckets() async throws {
        let results = [
            docResult("apple-docs://swiftui/view", source: "apple-docs"),
            docResult("samples://my-sample", source: "samples"),
            docResult("packages://apple/swift-async-algorithms/Foo.md", source: "packages"),
        ]
        let backend = Backend.LocalEmbedded(dataSource: FakeDataSource(results: results))
        let unified = try await backend.searchEverything(Model.UnifiedQuery(text: "", limitPerSource: 10))
        #expect(unified.docs.count == 1)
        #expect(unified.samples.projects.count == 1)
        #expect(unified.packages.count == 1)
        #expect(unified.packages.first?.owner == "apple")
        #expect(unified.packages.first?.repo == "swift-async-algorithms")
    }

    @Test("searchSamples reads projects and file hits through the sample reader")
    func searchSamples() async throws {
        let sampleReader = FakeSampleReader(
            projects: [sampleProject()],
            fileResults: [
                Sample.Index.FileSearchResult(
                    projectId: "landmarks",
                    path: "Sources/ContentView.swift",
                    filename: "ContentView.swift",
                    snippet: "struct ContentView",
                    rank: -2.5,
                ),
            ],
        )
        let backend = Backend.LocalEmbedded(dataSource: FakeDataSource(), sampleReader: sampleReader)
        let results = try await backend.searchSamples(Model.SampleQuery(
            text: "landmark",
            framework: "swiftui",
            floor: Model.PlatformFloor(iOS: "17.0"),
            includeFiles: true,
            limit: 5,
        ))

        #expect(results.projects.map(\.id.rawValue) == ["landmarks"])
        #expect(results.projects.first?.deploymentTargets[.iOS] == "17.0")
        #expect(results.files.first?.path == "Sources/ContentView.swift")
        #expect(results.files.first?.score == 2.5)

        let sampleCalls = await sampleReader.calls()
        #expect(sampleCalls.projectFramework == "swiftui")
        #expect(sampleCalls.projectMinIOS == "17.0")
        #expect(sampleCalls.filePlatform == "iOS")
        #expect(sampleCalls.fileMinVersion == "17.0")
    }

    @Test("sample listing and reads use the sample reader")
    func sampleBrowsing() async throws {
        let sampleReader = FakeSampleReader(
            projects: [sampleProject()],
            files: [Sample.Index.File(projectId: "landmarks", path: "Sources/ContentView.swift", content: "struct ContentView {}")],
        )
        let backend = Backend.LocalEmbedded(dataSource: FakeDataSource(), sampleReader: sampleReader)

        let listed = try await backend.listSamples(framework: "swiftui", limit: 10)
        #expect(listed.map(\.id.rawValue) == ["landmarks"])

        let project = try await backend.readSample(Model.SampleID("landmarks"))
        #expect(project.filePaths == ["Sources/ContentView.swift"])
        #expect(project.readme == "# Landmarks")

        let file = try await backend.readSampleFile(Model.SampleID("landmarks"), path: "Sources/ContentView.swift")
        #expect(file.filename == "ContentView.swift")
        #expect(file.language == "swift")
        #expect(file.contents == "struct ContentView {}")
    }

    @Test("searchSymbols uses the symbol reader and platform minima")
    func searchSymbols() async throws {
        let symbolReader = FakeSymbolReader(
            symbolResults: [
                symbolResult(uri: "apple-docs://swiftui/view", name: "View", kind: "struct"),
                symbolResult(uri: "apple-docs://swiftui/newview", name: "NewView", kind: "struct"),
            ],
            platformMinima: [
                "apple-docs://swiftui/view": Search.PlatformMinima(minIOS: "16.0"),
                "apple-docs://swiftui/newview": Search.PlatformMinima(minIOS: "18.0"),
            ],
        )
        let backend = Backend.LocalEmbedded(dataSource: FakeDataSource(), symbolReader: symbolReader)
        let hits = try await backend.searchSymbols(Model.SymbolQuery(
            text: "View",
            kind: .structure,
            isAsync: false,
            framework: "swiftui",
            floor: Model.PlatformFloor(iOS: "17.0"),
            limit: 10,
        ))

        #expect(hits.map(\.name) == ["View"])
        #expect(hits.first?.kind == .structure)
        #expect(hits.first?.attributes == ["@MainActor"])
        #expect(hits.first?.conformances == ["Sendable", "View"])

        let calls = await symbolReader.calls()
        #expect(calls.symbolKind == "struct")
        #expect(calls.symbolFramework == "swiftui")
        #expect(calls.fetchMinimaURIs == ["apple-docs://swiftui/view", "apple-docs://swiftui/newview"])
    }

    @Test("code intelligence methods dispatch to the symbol reader")
    func codeIntelligenceDispatch() async throws {
        let tree = Search.InheritanceTree(
            startURI: "apple-docs://uikit/uibutton",
            ancestors: [Search.InheritanceNode(uri: "apple-docs://uikit/uicontrol")],
            descendants: [],
        )
        let symbolReader = FakeSymbolReader(
            symbolResults: [symbolResult(uri: "apple-docs://uikit/uibutton", name: "UIButton", kind: "class")],
            inheritanceCandidates: [
                Search.InheritanceCandidate(uri: "apple-docs://swiftui/button", framework: "swiftui", title: "Button", kind: "struct"),
                Search.InheritanceCandidate(uri: "apple-docs://uikit/uibutton", framework: "uikit", title: "UIButton", kind: "class"),
            ],
            inheritanceTree: tree,
        )
        let backend = Backend.LocalEmbedded(dataSource: FakeDataSource(), symbolReader: symbolReader)

        _ = try await backend.searchConformances(to: "View", framework: "swiftui", limit: 3)
        _ = try await backend.searchPropertyWrappers("@State", framework: nil, limit: 4)
        _ = try await backend.searchConcurrency(.mainActor, framework: "swiftui", limit: 5)
        _ = try await backend.searchGenerics(constraint: "Sendable", framework: nil, limit: 6)
        let inheritance = try await backend.inheritance(of: "UIButton", direction: .ancestors, depth: 2, framework: "uikit")

        #expect(inheritance.startURI.rawValue == "apple-docs://uikit/uibutton")
        #expect(inheritance.ancestors.first?.title == "uicontrol")

        let calls = await symbolReader.calls()
        #expect(calls.protocolName == "View")
        #expect(calls.wrapper == "@State")
        #expect(calls.concurrencyPattern == "mainactor")
        #expect(calls.genericConstraint == "Sendable")
        #expect(calls.inheritanceStartURI == "apple-docs://uikit/uibutton")
        #expect(calls.inheritanceDirection == .up)
        #expect(calls.inheritanceDepth == 2)
    }

    @Test("missing optional reader slices fail honestly")
    func unsupportedVerb() async {
        let backend = Backend.LocalEmbedded(dataSource: FakeDataSource())
        await #expect(throws: Backend.Failure.self) {
            _ = try await backend.listSamples(framework: nil, limit: 10)
        }
        await #expect(throws: Backend.Failure.self) {
            _ = try await backend.searchSymbols(Model.SymbolQuery(text: "View"))
        }
        await #expect(throws: Backend.Failure.self) {
            _ = try await backend.searchPackages(Model.PackageQuery(text: "swift"))
        }
    }
}
