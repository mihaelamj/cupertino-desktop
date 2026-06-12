import AppModels
import BackendAPI
import CupertinoDataKit
import Foundation

public extension Backend {
    /// `Backend.Documentation` adapter for the local, in-process (embedded) path.
    ///
    /// GoF **Adapter**: it adapts cupertino's read contracts
    /// (`CupertinoDataKit.Search.DocumentReading`, `Search.SymbolReading`,
    /// `Sample.Index.Reader`, and `Search.PackagesSearcher`, the adaptees) to our own
    /// `Backend.Documentation` target,
    /// translating the adaptees' results into `AppModels` at the boundary. Nothing above
    /// this seam sees CupertinoDataKit, the corpus, or SQLite.
    ///
    /// The read implementation is a **constructor-injected strategy**
    /// (`any Search.DocumentReading`): the adapter is identical whether the data source
    /// is the real engine, an in-bundle reader, or a fake in tests, and it depends only
    /// on the named protocol, never on a concrete or on the `cupertino` package
    /// (docs/rules/dependency-injection.md). The composition root injects the concrete.
    ///
    actor LocalEmbedded: Documentation {
        private let dataSource: any Search.DocumentReading
        private let symbolReader: (any Search.SymbolReading)?
        private let sampleReader: (any Sample.Index.Reader)?
        private let packageSearcher: (any Search.PackagesSearcher)?

        public init(
            dataSource: any Search.DocumentReading,
            symbolReader: (any Search.SymbolReading)? = nil,
            sampleReader: (any Sample.Index.Reader)? = nil,
            packageSearcher: (any Search.PackagesSearcher)? = nil,
        ) {
            self.dataSource = dataSource
            self.symbolReader = symbolReader ?? (dataSource as? any Search.SymbolReading)
            self.sampleReader = sampleReader
            self.packageSearcher = packageSearcher ?? (dataSource as? any Search.PackagesSearcher)
        }

        // MARK: Connecting

        /// The injected data source is constructed ready (its corpus is resolved by the
        /// composition root), so there is nothing to open here.
        public func connect() async throws {}

        public func disconnect() async {
            await dataSource.disconnect()
            await sampleReader?.disconnect()
        }

        // MARK: FrameworkBrowsing

        public func listFrameworks() async throws -> [Model.Framework] {
            try await Self.frameworks(from: dataSource.listFrameworks())
        }

        public func listSources() async throws -> [Model.Source] {
            var activeSources: [Model.Source] = []
            var added = Set<Model.Source>()

            func add(_ source: Model.Source) {
                if !added.contains(source) {
                    added.insert(source)
                    activeSources.append(source)
                }
            }

            // 1. Try SourceIDProviding cast
            if let provider = dataSource as? any SourceIDProviding {
                for id in provider.sourceIDs {
                    add(Self.source(forID: id))
                }
            }

            // 2. If still empty, scan frameworks (e.g. for mock data sources in tests)
            if activeSources.isEmpty {
                if let counts = try? await dataSource.listFrameworks() {
                    for key in counts.keys {
                        let id = key.lowercased()
                        if id == "swift-evolution" {
                            add(.swiftEvolution)
                        } else if id == "swift-org" {
                            add(.swiftOrg)
                        } else if id == "swift-book" {
                            add(.swiftBook)
                        } else if ["components", "foundations", "general", "inputs", "patterns", "technologies"].contains(id) {
                            add(.hig)
                        } else if [
                            "appkit", "cocoa", "coreaudio", "coredata", "corefoundation", "coregraphics",
                            "coreimage", "coretext", "foundation", "objectivec", "performance",
                            "quartzcore", "security", "uikit",
                        ].contains(id) {
                            add(.appleArchive)
                        } else {
                            add(.appleDocs)
                        }
                    }
                }
            }

            // 3. Fallback if still empty
            if activeSources.isEmpty {
                add(.appleDocs)
            }

            // 4. Injected reader states
            if sampleReader != nil {
                add(.samples)
            }
            if packageSearcher != nil {
                add(.packages)
            }

            return activeSources
        }

        public func listSourceHierarchy(source: Model.Source, level: Int, parent: String?) async throws -> [Model.HierarchyItem] {
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
                let query = Model.DocsQuery(text: parent, sources: [source], framework: parent, limit: 100)
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

        private static func source(forID id: String) -> Model.Source {
            if let matched = Model.Source.allCases.first(where: { $0.scheme == id }) {
                return matched
            }
            if let matched = Model.Source.allCases.first(where: { $0.rawValue == id }) {
                return matched
            }
            return Model.Source(rawValue: id)
        }

        // MARK: DocumentReading

        public func readDocument(_ uri: Model.DocURI) async throws -> Model.DocPage {
            guard let markdown = try await dataSource.getDocumentContent(uri: uri.rawValue, format: .markdown) else {
                throw Failure.notFound(id: uri.rawValue)
            }
            return Self.page(uri: uri, markdown: markdown)
        }

        // MARK: Searching

        public func searchDocs(_ query: Model.DocsQuery) async throws -> [Model.DocHit] {
            // The contract's `search` takes a single optional source, so a one-source
            // query is expressed precisely. A subset of two or more cannot be passed in
            // one call: we search across all sources, then filter the hits down to the
            // selection below, which keeps the sources honest (no hit from a deselected
            // source leaks through) at the cost of possibly fewer than `limit` rows for
            // such queries. An empty or full selection means "all sources": no filter.
            let selected = query.sources
            let singleSource = selected.count == 1 ? selected.first?.scheme : nil
            let results = try await dataSource.search(
                query: query.text,
                source: singleSource,
                framework: query.framework,
                language: query.language,
                limit: query.limit,
                includeArchive: selected.isEmpty || selected.contains(.appleArchive),
                minIOS: query.floor.iOS,
                minMacOS: query.floor.macOS,
                minTvOS: query.floor.tvOS,
                minWatchOS: query.floor.watchOS,
                minVisionOS: query.floor.visionOS,
                minSwift: query.floor.swift,
            )
            let hits = results.compactMap(Self.hit(from:))
            guard selected.count > 1, selected.count < Model.Source.allCases.count else { return hits }
            return hits.filter { selected.contains($0.source) }
        }

        public func searchSamples(_ query: Model.SampleQuery) async throws -> Model.SampleResults {
            guard let sampleReader else {
                throw Failure.unsupported(operation: "searchSamples")
            }
            guard !query.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return Model.SampleResults(projects: [], files: [])
            }
            let projects = try await sampleReader.searchProjects(
                query: query.text,
                framework: query.framework,
                limit: query.limit,
                minIOS: query.floor.iOS,
                minMacOS: query.floor.macOS,
                minTvOS: query.floor.tvOS,
                minWatchOS: query.floor.watchOS,
                minVisionOS: query.floor.visionOS,
            )
            let files: [Sample.Index.FileSearchResult]
            if query.includeFiles {
                let floor = Self.sampleFileFloor(from: query.floor)
                files = try await sampleReader.searchFiles(
                    query: query.text,
                    projectId: nil,
                    fileExtension: nil,
                    limit: query.limit,
                    platform: floor?.platform,
                    minVersion: floor?.minVersion,
                )
            } else {
                files = []
            }
            return Model.SampleResults(
                projects: projects.map { Self.sampleProject(from: $0) },
                files: files.map(Self.sampleFileHit(from:)),
            )
        }

        public func searchPackages(_ query: Model.PackageQuery) async throws -> [Model.PackageHit] {
            guard let packageSearcher else {
                throw Failure.unsupported(operation: "searchPackages")
            }
            return try await Self.packageHits(
                from: packageSearcher,
                text: query.text,
                limit: query.limit,
                floor: query.floor,
                appleImport: query.appleImport,
            )
        }

        /// One search across every source, bucketed by source into the unified shape:
        /// doc-like sources become `DocHit`s, `samples` rows become `SampleProject`s, and
        /// `packages` rows become `PackageHit`s. Each bucket is capped at `limitPerSource`.
        /// The docs pass still uses `DocumentReading`; when the dedicated package reader is
        /// available, it also fills the package bucket without exposing storage to desktop.
        public func searchEverything(_ query: Model.UnifiedQuery) async throws -> Model.UnifiedResults {
            let results = try await dataSource.search(
                query: query.text,
                source: nil,
                framework: query.framework,
                language: nil,
                limit: query.limitPerSource * Model.Source.allCases.count,
                includeArchive: true,
                minIOS: query.floor.iOS,
                minMacOS: query.floor.macOS,
                minTvOS: query.floor.tvOS,
                minWatchOS: query.floor.watchOS,
                minVisionOS: query.floor.visionOS,
                minSwift: query.floor.swift,
            )
            var docs: [Model.DocHit] = []
            var projects: [Model.SampleProject] = []
            var packages: [Model.PackageHit] = []
            for result in results {
                if result.source == Model.Source.samples.scheme {
                    if projects.count < query.limitPerSource { projects.append(Self.sampleProject(from: result)) }
                } else if result.source == Model.Source.packages.scheme {
                    if packages.count < query.limitPerSource { packages.append(Self.packageHit(from: result)) }
                } else if docs.count < query.limitPerSource, let hit = Self.hit(from: result) {
                    docs.append(hit)
                }
            }
            if packages.count < query.limitPerSource, let packageSearcher {
                let hits = try await Self.packageHits(
                    from: packageSearcher,
                    text: query.text,
                    limit: query.limitPerSource,
                    floor: query.floor,
                    appleImport: query.framework,
                )
                for hit in hits where packages.count < query.limitPerSource && !packages.contains(where: { Self.samePackage($0, hit) }) {
                    packages.append(hit)
                }
            }
            return Model.UnifiedResults(docs: docs, samples: Model.SampleResults(projects: projects, files: []), packages: packages)
        }

        // MARK: SampleBrowsing

        public func listSamples(framework: String?, limit: Int) async throws -> [Model.SampleProject] {
            guard let sampleReader else {
                throw Failure.unsupported(operation: "listSamples")
            }
            let projects = try await sampleReader.listProjects(framework: framework, limit: limit)
            return projects.map { Self.sampleProject(from: $0) }
        }

        public func readSample(_ id: Model.SampleID) async throws -> Model.SampleProject {
            guard let sampleReader else {
                throw Failure.unsupported(operation: "readSample")
            }
            guard let project = try await sampleReader.getProject(id: id.rawValue) else {
                throw Failure.notFound(id: id.rawValue)
            }
            let files = try await sampleReader.listFiles(projectId: id.rawValue, folder: nil)
            return Self.sampleProject(from: project, filePaths: files.map(\.path).sorted())
        }

        public func readSampleFile(_ id: Model.SampleID, path: String) async throws -> Model.SampleFile {
            guard let sampleReader else {
                throw Failure.unsupported(operation: "readSampleFile")
            }
            guard let file = try await sampleReader.getFile(projectId: id.rawValue, path: path) else {
                throw Failure.notFound(id: "\(id.rawValue):\(path)")
            }
            return Self.sampleFile(from: file)
        }

        // MARK: CodeIntelligence

        public func searchSymbols(_ query: Model.SymbolQuery) async throws -> [Model.SymbolHit] {
            guard let symbolReader else {
                throw Failure.unsupported(operation: "searchSymbols")
            }
            let results = try await symbolReader.searchSymbols(
                query: query.text,
                kind: Self.backendKind(from: query.kind),
                isAsync: query.isAsync,
                framework: query.framework,
                limit: query.limit,
            )
            return try await Self.symbolHits(from: results, floor: query.floor, using: symbolReader)
        }

        public func searchConformances(to protocolName: String, framework: String?, limit: Int) async throws -> [Model.SymbolHit] {
            guard let symbolReader else {
                throw Failure.unsupported(operation: "searchConformances")
            }
            let results = try await symbolReader.searchConformances(protocolName: protocolName, framework: framework, limit: limit)
            return results.compactMap(Self.symbolHit(from:))
        }

        public func searchPropertyWrappers(_ wrapper: String, framework: String?, limit: Int) async throws -> [Model.SymbolHit] {
            guard let symbolReader else {
                throw Failure.unsupported(operation: "searchPropertyWrappers")
            }
            let results = try await symbolReader.searchPropertyWrappers(wrapper: wrapper, framework: framework, limit: limit)
            return results.compactMap(Self.symbolHit(from:))
        }

        public func searchConcurrency(_ pattern: Model.ConcurrencyPattern, framework: String?, limit: Int) async throws -> [Model.SymbolHit] {
            guard let symbolReader else {
                throw Failure.unsupported(operation: "searchConcurrency")
            }
            let results = try await symbolReader.searchConcurrencyPatterns(
                pattern: Self.backendConcurrencyPattern(from: pattern),
                framework: framework,
                limit: limit,
            )
            return results.compactMap(Self.symbolHit(from:))
        }

        public func searchGenerics(constraint: String, framework: String?, limit: Int) async throws -> [Model.SymbolHit] {
            guard let symbolReader else {
                throw Failure.unsupported(operation: "searchGenerics")
            }
            let results = try await symbolReader.searchByGenericConstraint(constraint: constraint, framework: framework, limit: limit)
            return results.compactMap(Self.symbolHit(from:))
        }

        public func inheritance(of symbol: String, direction: Model.InheritanceDirection, depth: Int, framework: String?) async throws -> Model.InheritanceTree {
            guard let symbolReader else {
                throw Failure.unsupported(operation: "inheritance")
            }
            let candidates = try await symbolReader.resolveSymbolURIs(title: symbol)
            guard let candidate = Self.inheritanceCandidate(from: candidates, framework: framework) else {
                throw Failure.notFound(id: symbol)
            }
            let tree = try await symbolReader.walkInheritance(
                startURI: candidate.uri,
                direction: Self.backendInheritanceDirection(from: direction),
                maxDepth: depth,
            )
            guard let mapped = Self.inheritanceTree(from: tree) else {
                throw Failure.decoding("inheritance returned an invalid URI for \(symbol)")
            }
            return mapped
        }
    }
}

/// Protocol to dynamically retrieve the configured source IDs from the database engine
public protocol SourceIDProviding: Sendable {
    var sourceIDs: [String] { get }
}
