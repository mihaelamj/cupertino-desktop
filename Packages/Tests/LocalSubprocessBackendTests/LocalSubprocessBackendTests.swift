import AppModels
import BackendAPI
import Foundation
@testable import LocalSubprocessBackend
import SwiftMCPClient
import SwiftMCPClientAPI
import SwiftMCPSubprocessTransport
import SwiftMCPTransport
import Testing

@Suite("LocalSubprocess adapter")
struct LocalSubprocessBackendTests {
    /// Hermetic: a fake `Client.MCP` returns the real `list_frameworks` markdown shape;
    /// the adapter parses it into `Model.Framework`. No process, no MCP wire.
    @Test("listFrameworks parses the markdown table")
    func parsesFrameworks() async throws {
        let markdown = """
        # Available Frameworks

        Total documents: **352712**

        | Framework | Documents |
        |-----------|----------:|
        | `swiftui` | 8679 |
        | `foundation` | 13,649 |
        """
        let backend = Backend.LocalSubprocess(client: StubClient(toolText: markdown))
        let frameworks = try await backend.listFrameworks()

        #expect(frameworks.count == 2)
        let swiftui = frameworks.first { $0.id == "swiftui" }
        #expect(swiftui?.documentCount == 8679)
        // Comma-grouped counts parse too.
        #expect(frameworks.first { $0.id == "foundation" }?.documentCount == 13649)
        // Header and separator rows are skipped.
        #expect(!frameworks.contains { $0.id == "Framework" })
    }

    @Test("the parser ignores non-table noise")
    func parserIgnoresNoise() {
        let frameworks = Backend.LocalSubprocess.parseFrameworks("no table here\njust prose")
        #expect(frameworks.isEmpty)
    }

    /// `searchDocs` parses the per-source ranked-list markdown the `search` tool
    /// returns: a numbered block per hit, URI/framework/score bullets, a snippet, and a
    /// trailing footer that must be ignored. Fixture mirrors real `search` output.
    @Test("searchDocs parses per-source ranked results and ignores the footer")
    func parsesDocSearch() async throws {
        let markdown = """
        # Search Results for "animation"

        _Source: **apple-docs**_

        Found **2** results:

        ## 1. Animation | Apple Developer Documentation

        - **Framework:** `swiftui`
        - **URI:** `apple-docs://swiftui/animation`
        - **Score:** 2000.00
        - **Words:** 288
        - **Symbols:** `struct Animation`

        The way a view changes over time to create a smooth visual transition.

        ---

        ## 2. Animation | Apple Developer Documentation

        - **Framework:** `appkit`
        - **URI:** `apple-docs://appkit/animation`
        - **Score:** 3421.41

        Animate your views and other content.

        ---

        💡 **Other sources:** samples, hig, apple-archive, or `all`
        """
        let backend = Backend.LocalSubprocess(client: StubClient(toolText: markdown))
        let hits = try await backend.searchDocs(Model.DocsQuery(text: "animation"))

        #expect(hits.count == 2)
        #expect(hits.first?.uri.rawValue == "apple-docs://swiftui/animation")
        #expect(hits.first?.framework == "swiftui")
        #expect(hits.first?.source == .appleDocs)
        #expect(hits.first?.score == 2000.0)
        #expect(hits.first?.snippet.contains("smooth visual transition") == true)
        // The "Other sources" footer is not a numbered block, so it produces no hit.
        #expect(!hits.contains { $0.title.contains("Other sources") })
    }

    @Test("an empty query short-circuits without calling the tool")
    func emptyQueryReturnsNoHits() async throws {
        let backend = Backend.LocalSubprocess(client: StubClient(toolText: "should not be parsed"))
        #expect(try await backend.searchDocs(Model.DocsQuery(text: "")).isEmpty)
    }

    /// `searchEverything` parses the unified (no-source) markdown, whose results are
    /// grouped under per-source section headers, into the doc, sample, and package
    /// buckets. Fixture mirrors real unified `search` output.
    @Test("searchEverything buckets unified results by source section")
    func parsesUnifiedSearch() async throws {
        let markdown = """
        # Unified Search: "animation"

        **Total: 3 results** found in 3 sources

        ## 📚 Apple Documentation (1)

        - **Animation | Apple Developer Documentation**
          - The way a view changes over time to create a smooth visual transition.
          - URI: `apple-docs://swiftui/animation`
          - Symbols: `struct Animation`

        ## 📦 Sample Code (1)

        - **Detecting animal body poses with Vision**
          - Draw the skeleton of an animal by using Vision.
          - ID: `vision-detecting-animal-body-poses-with-vision`
          - Frameworks: vision

        ## 📦 Swift Packages (1)

        - **NIOTransportServices**
          - Extensions for SwiftNIO to support Apple platforms.
          - URI: `packages://apple/swift-nio-transport-services/Sources/NIOTransportServices/Docs.docc/index.md`

        ---
        """
        let backend = Backend.LocalSubprocess(client: StubClient(toolText: markdown))
        let results = try await backend.searchEverything(Model.UnifiedQuery(text: "animation"))

        #expect(results.docs.count == 1)
        #expect(results.docs.first?.uri.rawValue == "apple-docs://swiftui/animation")
        #expect(results.docs.first?.source == .appleDocs)

        #expect(results.samples.projects.count == 1)
        #expect(results.samples.projects.first?.id.rawValue == "vision-detecting-animal-body-poses-with-vision")
        #expect(results.samples.projects.first?.frameworks == ["vision"])

        #expect(results.packages.count == 1)
        #expect(results.packages.first?.owner == "apple")
        #expect(results.packages.first?.repo == "swift-nio-transport-services")
        #expect(results.packages.first?.path == "Sources/NIOTransportServices/Docs.docc/index.md")
    }

    /// `readDocument` decodes the JSON `read_document` returns and carries `rawMarkdown`
    /// through as the page body. Fixture mirrors the real JSON shape.
    @Test("readDocument decodes the JSON page and keeps the full body")
    func parsesReadDocument() async throws {
        let json = """
        {
          "title": "View | Apple Developer Documentation",
          "abstract": "A type that represents part of your app's user interface.",
          "rawMarkdown": "# View\\n\\nA type that represents part of your app's user interface.",
          "declaration": { "code": "protocol View", "language": "swift" },
          "sections": [ { "title": "Overview", "content": "You create custom views." } ]
        }
        """
        let backend = Backend.LocalSubprocess(client: StubClient(toolText: json))
        let uri = try #require(Model.DocURI("apple-docs://swiftui/view"))
        let page = try await backend.readDocument(uri)

        #expect(page.title == "View | Apple Developer Documentation")
        #expect(page.source == .appleDocs)
        #expect(page.markdown.contains("A type that represents part of your app's user interface."))
        #expect(page.declaration?.code == "protocol View")
        #expect(page.sections.first?.title == "Overview")
    }

    /// Opt-in integration test against the installed `cupertino` binary. Enable with
    /// `CUPERTINO_INTEGRATION=1 swift test`. Time-limited so a stuck server cannot hang.
    @Test(
        "listFrameworks returns live data from the cupertino binary",
        .enabled(if: ProcessInfo.processInfo.environment["CUPERTINO_INTEGRATION"] == "1"),
        .timeLimit(.minutes(1)),
    )
    func liveListFrameworks() async throws {
        let transport = Transport.Subprocess(command: "cupertino", arguments: ["serve"])
        let backend = Backend.LocalSubprocess(client: MCPClient(transport: transport))
        try await backend.connect()
        defer { Task { await backend.disconnect() } }

        let frameworks = try await backend.listFrameworks()
        #expect(!frameworks.isEmpty)
        #expect(frameworks.contains { $0.id == "swiftui" })
    }

    /// Opt-in integration test that exercises the implemented search/read verbs against
    /// the real binary, catching any drift between the server's markdown/JSON and the
    /// adapter's parsers. Enable with `CUPERTINO_INTEGRATION=1 swift test`.
    @Test(
        "searchDocs, searchEverything, and readDocument return live data",
        .enabled(if: ProcessInfo.processInfo.environment["CUPERTINO_INTEGRATION"] == "1"),
        .timeLimit(.minutes(1)),
    )
    func liveSearchAndRead() async throws {
        let transport = Transport.Subprocess(command: "cupertino", arguments: ["serve"])
        let backend = Backend.LocalSubprocess(client: MCPClient(transport: transport))
        try await backend.connect()
        defer { Task { await backend.disconnect() } }

        let hits = try await backend.searchDocs(Model.DocsQuery(text: "animation", sources: [.appleDocs], limit: 5))
        #expect(!hits.isEmpty)
        let first = try #require(hits.first)
        #expect(first.uri.rawValue.hasPrefix("apple-docs://"))

        let page = try await backend.readDocument(first.uri)
        #expect(!page.markdown.isEmpty)

        let unified = try await backend.searchEverything(Model.UnifiedQuery(text: "animation", limitPerSource: 5))
        #expect(!unified.docs.isEmpty || !unified.packages.isEmpty || !unified.samples.projects.isEmpty)
    }
}

/// A `Client.MCP` double that returns canned tool text. Possible only because the
/// adapter depends on the `Client.MCP` protocol, not the concrete client.
private actor StubClient: Client.MCP {
    let toolText: String
    init(toolText: String) {
        self.toolText = toolText
    }

    func connect() async throws {}
    func disconnect() async {}
    func callTool(_: String, arguments _: [String: Client.Argument]) async throws -> String {
        toolText
    }

    func readResource(_: String) async throws -> String {
        toolText
    }
}
