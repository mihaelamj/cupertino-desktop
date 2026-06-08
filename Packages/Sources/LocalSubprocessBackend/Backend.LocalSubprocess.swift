import AppModels
import BackendAPI
import Foundation
import SwiftMCPClientAPI

public extension Backend {
    /// `Backend.Documentation` adapter for the **local, out-of-process** path: it
    /// talks to a `cupertino serve` subprocess on the same machine. The fact that
    /// the boundary is crossed with MCP/JSON-RPC is a detail of the client it holds
    /// (`Client.MCP`), not of this adapter; nothing above the protocol sees MCP.
    /// The sibling local path is `Backend.LocalEmbedded`, which reads the local
    /// corpus in process without MCP.
    ///
    /// The verb-to-tool mapping is docs/PROTOCOL.md section 4: `read_document`
    /// returns JSON (decoded straight into `DocPage`); the search-list tools return
    /// the server's ranked markdown, which this adapter parses (see the parsing
    /// extension) into `AppModels`. Verbs no feature drives yet still fail honestly
    /// with `Failure.unsupported`.
    actor LocalSubprocess: Documentation {
        private let client: any Client.MCP

        public init(client: any Client.MCP) {
            self.client = client
        }

        // MARK: Connecting

        public func connect() async throws {
            try await client.connect()
        }

        public func disconnect() async {
            await client.disconnect()
        }

        // MARK: FrameworkBrowsing

        public func listFrameworks() async throws -> [Model.Framework] {
            let markdown = try await client.callTool("list_frameworks", arguments: [:])
            return Self.parseFrameworks(markdown)
        }

        /// Parse the `list_frameworks` markdown table (rows like ``| `swiftui` | 8679 |``)
        /// into `Model.Framework`. Parsing lives here, inside the adapter, never above
        /// the protocol. The table gives the lowercased id and a document count; we use
        /// the id as the display name until a richer source provides one.
        static func parseFrameworks(_ markdown: String) -> [Model.Framework] {
            markdown.split(whereSeparator: \.isNewline).compactMap { rawLine in
                let cells = rawLine.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                guard cells.count >= 2,
                      cells[0].hasPrefix("`"), cells[0].hasSuffix("`")
                else { return nil }
                let id = String(cells[0].dropFirst().dropLast())
                guard !id.isEmpty,
                      let count = Int(cells[1].replacingOccurrences(of: ",", with: ""))
                else { return nil }
                return Model.Framework(id: id, name: id, documentCount: count)
            }
        }

        // MARK: DocumentReading

        /// `read_document` returns JSON by default, so the reader gets a structured
        /// page without scraping markdown. We decode the fields we model and carry the
        /// server's `rawMarkdown` through as the body.
        public func readDocument(_ uri: Model.DocURI) async throws -> Model.DocPage {
            let json = try await client.callTool("read_document", arguments: [
                "uri": .string(uri.rawValue),
                "format": .string("json"),
            ])
            guard let data = json.data(using: .utf8) else {
                throw Failure.decoding("read_document returned non-UTF8 content")
            }
            let raw: RawDocument
            do {
                raw = try JSONDecoder().decode(RawDocument.self, from: data)
            } catch {
                throw Failure.decoding("read_document JSON did not match the expected shape: \(error)")
            }
            let body = (raw.rawMarkdown?.isEmpty == false ? raw.rawMarkdown : nil)
                ?? raw.abstract ?? raw.title ?? uri.rawValue
            return Model.DocPage(
                uri: uri,
                source: Self.source(of: uri),
                title: raw.title ?? uri.rawValue,
                abstract: raw.abstract,
                declaration: raw.declaration.map { Model.DocPage.Declaration(code: $0.code, language: $0.language) },
                markdown: body,
                sections: raw.sections?.map { Model.DocPage.Section(title: $0.title, markdown: $0.content) } ?? [],
            )
        }

        // MARK: Searching

        /// `search` per selected doc-like source, parsing each response's ranked
        /// markdown blocks into `DocHit`. `samples`/`packages` carry a different nature
        /// and are excluded here (they answer through `searchEverything`). The platform
        /// floor maps to cupertino's `min_*` arguments, so filtering happens server-side.
        public func searchDocs(_ query: Model.DocsQuery) async throws -> [Model.DocHit] {
            guard !query.text.isEmpty else { return [] }
            let requested = query.sources.intersection(Self.docLikeSources)
            let sources = requested.isEmpty ? [Model.Source.appleDocs] : requested
            var hits: [Model.DocHit] = []
            for source in sources.sorted(by: { $0.scheme < $1.scheme }) {
                let markdown = try await client.callTool("search", arguments: Self.searchArguments(query, source: source))
                hits.append(contentsOf: Self.parseDocHits(markdown))
            }
            return Array(hits.prefix(max(0, query.limit)))
        }

        public func searchSamples(_: Model.SampleQuery) async throws -> Model.SampleResults {
            throw Failure.unsupported(operation: "searchSamples")
        }

        public func searchPackages(_: Model.PackageQuery) async throws -> [Model.PackageHit] {
            throw Failure.unsupported(operation: "searchPackages")
        }

        /// The unified scope: one `search` with no source returns every source's hits
        /// already bucketed under section headers, which we parse into the doc, sample,
        /// and package buckets in a single round-trip.
        public func searchEverything(_ query: Model.UnifiedQuery) async throws -> Model.UnifiedResults {
            guard !query.text.isEmpty else {
                return Model.UnifiedResults(docs: [], samples: Model.SampleResults(projects: [], files: []), packages: [])
            }
            let markdown = try await client.callTool("search", arguments: Self.unifiedArguments(query))
            return Self.parseUnified(markdown)
        }

        // MARK: SampleBrowsing

        public func listSamples(framework _: String?, limit _: Int) async throws -> [Model.SampleProject] {
            throw Failure.unsupported(operation: "listSamples")
        }

        public func readSample(_: Model.SampleID) async throws -> Model.SampleProject {
            throw Failure.unsupported(operation: "readSample")
        }

        public func readSampleFile(_: Model.SampleID, path _: String) async throws -> Model.SampleFile {
            throw Failure.unsupported(operation: "readSampleFile")
        }

        // MARK: CodeIntelligence

        public func searchSymbols(_: Model.SymbolQuery) async throws -> [Model.SymbolHit] {
            throw Failure.unsupported(operation: "searchSymbols")
        }

        public func searchConformances(to _: String, framework _: String?, limit _: Int) async throws -> [Model.SymbolHit] {
            throw Failure.unsupported(operation: "searchConformances")
        }

        public func searchPropertyWrappers(_: String, framework _: String?, limit _: Int) async throws -> [Model.SymbolHit] {
            throw Failure.unsupported(operation: "searchPropertyWrappers")
        }

        public func searchConcurrency(_: Model.ConcurrencyPattern, framework _: String?, limit _: Int) async throws -> [Model.SymbolHit] {
            throw Failure.unsupported(operation: "searchConcurrency")
        }

        public func searchGenerics(constraint _: String, framework _: String?, limit _: Int) async throws -> [Model.SymbolHit] {
            throw Failure.unsupported(operation: "searchGenerics")
        }

        public func inheritance(of _: String, direction _: Model.InheritanceDirection, depth _: Int, framework _: String?) async throws -> Model.InheritanceTree {
            throw Failure.unsupported(operation: "inheritance")
        }
    }
}
