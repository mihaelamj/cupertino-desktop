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

        private var isConnected = false

        public func connect() async throws {
            guard !isConnected else { return }
            try await client.connect()
            isConnected = true
        }

        public func disconnect() async {
            await client.disconnect()
            isConnected = false
        }

        // MARK: FrameworkBrowsing

        public func listFrameworks() async throws -> [Model.Framework] {
            let markdown = try await client.callTool("list_frameworks", arguments: [:])
            return Self.parseFrameworks(markdown)
        }

        public func listSources() async throws -> [Model.Source] {
            // TODO: (epic: desktop) Ask the cupertino MCP server directly for active sources.
            // Currently, cupertino's MCP server does not expose a list_sources or list_databases tool.
            // As a temporary workaround, we scan the standard ~/.cupertino folder on macOS to discover
            // which SQLite databases exist. Once the cupertino backend implements the list_sources MCP tool,
            // this local filesystem scanning should be replaced by a callTool("list_sources", arguments: [:]) call.
            let fileManager = FileManager.default
            let homeDir = fileManager.homeDirectoryForCurrentUser
            let cupertinoDir = homeDir.appendingPathComponent(".cupertino")

            let dbMapping: [(filename: String, source: Model.Source)] = [
                ("apple-documentation.db", .appleDocs),
                ("hig.db", .hig),
                ("swift-evolution.db", .swiftEvolution),
                ("swift-org.db", .swiftOrg),
                ("swift-book.db", .swiftBook),
                ("apple-archive.db", .appleArchive),
                ("apple-sample-code.db", .samples),
                ("packages.db", .packages),
            ]

            var activeSources: [Model.Source] = []
            for mapping in dbMapping {
                let dbPath = cupertinoDir.appendingPathComponent(mapping.filename).path
                if fileManager.fileExists(atPath: dbPath) {
                    activeSources.append(mapping.source)
                }
            }

            if activeSources.isEmpty {
                return Model.Source.allCases
            }
            return activeSources
        }

        public func listSourceHierarchy(source: Model.Source, level: Int, parent: String?) async throws -> [Model.HierarchyItem] {
            do {
                var args: [String: Client.Argument] = [
                    "source": .string(source.scheme),
                    "level": .int(level),
                ]
                if let parent {
                    args["parent"] = .string(parent)
                }
                let json = try await client.callTool("list_source_hierarchy", arguments: args)
                guard let data = json.data(using: .utf8) else {
                    throw Failure.decoding("list_source_hierarchy returned non-UTF8 content")
                }
                return try JSONDecoder().decode([Model.HierarchyItem].self, from: data)
            } catch {
                return try await simulateSourceHierarchy(source: source, level: level, parent: parent)
            }
        }

        private func simulateSourceHierarchy(source: Model.Source, level: Int, parent: String?) async throws -> [Model.HierarchyItem] {
            if level == 1 {
                switch source {
                case .hig:
                    let sections = [
                        ("components", "Components", "Buttons, menus, toggles, etc."),
                        ("foundations", "Foundations", "Colors, typography, layout, etc."),
                        ("general", "General", "General design principles"),
                        ("inputs", "Inputs", "Keyboard, mouse, touch, gestures, etc."),
                        ("patterns", "Patterns", "Common interaction patterns"),
                        ("technologies", "Technologies", "Apple-specific technologies"),
                    ]
                    return sections.map { id, title, desc in
                        Model.HierarchyItem(id: id, title: title, description: desc, hasChildren: true)
                    }
                case .swiftEvolution:
                    return [
                        Model.HierarchyItem(
                            id: "swift-evolution",
                            title: "Swift Evolution",
                            description: "Proposals for changes to Swift",
                            hasChildren: true,
                        ),
                    ]
                case .swiftOrg:
                    return [
                        Model.HierarchyItem(
                            id: "swift-org",
                            title: "Swift.org Articles",
                            description: "Documentation and articles from swift.org",
                            hasChildren: true,
                        ),
                    ]
                case .swiftBook:
                    return [
                        Model.HierarchyItem(
                            id: "swift-book",
                            title: "The Swift Programming Language Book",
                            description: "Chapters of the official Swift book",
                            hasChildren: true,
                        ),
                    ]
                case .samples:
                    return [
                        Model.HierarchyItem(
                            id: "samples",
                            title: "Sample Projects",
                            description: "Official Apple sample projects",
                            hasChildren: true,
                        ),
                    ]
                case .packages:
                    return [
                        Model.HierarchyItem(
                            id: "packages",
                            title: "Swift Packages",
                            description: "Indexed third-party Swift packages",
                            hasChildren: true,
                        ),
                    ]
                case .appleDocs:
                    let frameworks = try await listFrameworks()
                    return frameworks.filter { belongs(framework: $0, to: .appleDocs) }.map { framework in
                        Model.HierarchyItem(
                            id: framework.id,
                            title: framework.displayName,
                            description: "\(framework.documentCount) documents",
                            hasChildren: true,
                        )
                    }
                case .appleArchive:
                    let frameworks = try await listFrameworks()
                    return frameworks.filter { belongs(framework: $0, to: .appleArchive) }.map { framework in
                        Model.HierarchyItem(
                            id: framework.id,
                            title: framework.displayName,
                            description: "\(framework.documentCount) documents",
                            hasChildren: true,
                        )
                    }
                default:
                    let frameworks = try await listFrameworks()
                    return frameworks.filter { belongs(framework: $0, to: source) }.map { framework in
                        Model.HierarchyItem(
                            id: framework.id,
                            title: framework.displayName,
                            description: "\(framework.documentCount) documents",
                            hasChildren: true,
                        )
                    }
                }
            } else if level == 2 {
                guard let parent else { return [] }
                let query = Model.DocsQuery(text: parent, sources: [source], framework: parent, limit: 100_000)
                let hits = try await searchDocs(query)
                return hits.map { hit in
                    Model.HierarchyItem(
                        id: hit.uri.rawValue,
                        title: hit.title,
                        description: hit.snippet,
                        hasChildren: false,
                    )
                }
            }
            return []
        }

        private func belongs(framework: Model.Framework, to source: Model.Source) -> Bool {
            let id = framework.id.lowercased()
            switch source {
            case .appleDocs:
                let nonAppleDocs: Set = [
                    "swift-evolution", "swift-org", "swift-book",
                    "components", "foundations", "general", "inputs", "patterns", "technologies",
                    "cocoa", "objectivec", "appkit", "samples", "packages",
                ]
                return !nonAppleDocs.contains(id)
            case .appleArchive:
                let archiveFrameworks: Set = [
                    "appkit", "cocoa", "coreaudio", "coredata", "corefoundation", "coregraphics",
                    "coreimage", "coretext", "foundation", "objectivec", "performance",
                    "quartzcore", "security", "uikit",
                ]
                return archiveFrameworks.contains(id)
            case .hig:
                return ["components", "foundations", "general", "inputs", "patterns", "technologies"].contains(id)
            case .swiftEvolution:
                return id == "swift-evolution"
            case .swiftOrg:
                return id == "swift-org"
            case .swiftBook:
                return id == "swift-book"
            case .samples:
                return id == "samples"
            case .packages:
                return id == "packages"
            default:
                return id == source.rawValue.lowercased()
            }
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
            if uri.rawValue.hasPrefix("samples://") {
                let rawPath = uri.rawValue.replacingOccurrences(of: "samples://", with: "")
                let projectId = rawPath.hasSuffix("/view") ? String(rawPath.dropLast(5)) : rawPath

                let json = try await client.callTool("read_sample", arguments: [
                    "project_id": .string(projectId),
                    "format": .string("json"),
                ])
                guard let data = json.data(using: .utf8) else {
                    throw Failure.decoding("read_sample returned non-UTF8 content")
                }

                struct RawSample: Decodable {
                    let id: String
                    let title: String
                    let description: String
                    let frameworks: [String]
                    let readme: String?
                }

                let raw: RawSample
                do {
                    raw = try JSONDecoder().decode(RawSample.self, from: data)
                } catch {
                    throw Failure.decoding("read_sample JSON did not match: \(error)")
                }

                let body = (raw.readme?.isEmpty == false ? raw.readme : nil)
                    ?? raw.description
                    ?? raw.title
                    ?? uri.rawValue
                return Model.DocPage(
                    uri: uri,
                    source: .samples,
                    title: raw.title,
                    abstract: raw.description,
                    declaration: nil,
                    markdown: body,
                    sections: [],
                )
            }

            if uri.rawValue.hasPrefix("packages://") {
                let rawPath = uri.rawValue.replacingOccurrences(of: "packages://", with: "")
                let content = try await client.callTool("read_document", arguments: [
                    "uri": .string(rawPath),
                    "format": .string("markdown"),
                ])
                let filename = rawPath.split(separator: "/").last.map(String.init) ?? uri.rawValue
                let body = filename.hasSuffix(".swift") ? "```swift\n\(content)\n```" : content
                return Model.DocPage(
                    uri: uri,
                    source: .packages,
                    title: filename,
                    abstract: nil,
                    declaration: nil,
                    markdown: body,
                    sections: [],
                )
            }

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
                if source == .samples {
                    hits.append(contentsOf: Self.parseSampleDocHits(markdown))
                } else {
                    hits.append(contentsOf: Self.parseDocHits(markdown))
                }
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
