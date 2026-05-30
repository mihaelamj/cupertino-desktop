import AppModels
import BackendAPI
import CupertinoDataKit
import Foundation

public extension Backend {
    /// `Backend.Documentation` adapter for the local, in-process (iOS) path.
    ///
    /// GoF **Adapter**: it adapts cupertino's read contract
    /// (`CupertinoDataKit.Search.DocumentReading`, the adaptee) to our own
    /// `Backend.Documentation` target, translating the adaptee's `Search.*` results into
    /// `AppModels` at the boundary. Nothing above this seam sees CupertinoDataKit, the
    /// corpus, or SQLite.
    ///
    /// The read implementation is a **constructor-injected strategy**
    /// (`any Search.DocumentReading`): the adapter is identical whether the data source
    /// is the real engine, an in-bundle reader, or a fake in tests, and it depends only
    /// on the named protocol, never on a concrete or on the `cupertino` package
    /// (docs/rules/dependency-injection.md). The composition root injects the concrete.
    ///
    /// It adopts only the `DocumentReading` slice today; the sample and
    /// code-intelligence verbs stay `Failure.unsupported` until the matching
    /// CupertinoDataKit slices (`Sample.Index.Reader`, `Search.SymbolReading`) are wired.
    actor LocalEmbedded: Documentation {
        private let dataSource: any Search.DocumentReading

        public init(dataSource: any Search.DocumentReading) {
            self.dataSource = dataSource
        }

        // MARK: Connecting

        /// The injected data source is constructed ready (its corpus is resolved by the
        /// composition root), so there is nothing to open here.
        public func connect() async throws {}

        public func disconnect() async {
            await dataSource.disconnect()
        }

        // MARK: FrameworkBrowsing

        public func listFrameworks() async throws -> [Model.Framework] {
            try await Self.frameworks(from: dataSource.listFrameworks())
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

        public func searchSamples(_: Model.SampleQuery) async throws -> Model.SampleResults {
            throw Failure.unsupported(operation: "searchSamples")
        }

        public func searchPackages(_: Model.PackageQuery) async throws -> [Model.PackageHit] {
            throw Failure.unsupported(operation: "searchPackages")
        }

        /// One search across every source, bucketed by source into the unified shape:
        /// doc-like sources become `DocHit`s, `samples` rows become `SampleProject`s, and
        /// `packages` rows become `PackageHit`s. Each bucket is capped at `limitPerSource`.
        /// This reuses the `DocumentReading` slice rather than needing dedicated sample or
        /// package readers; the real engine can answer each source natively later.
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
            return Model.UnifiedResults(docs: docs, samples: Model.SampleResults(projects: projects, files: []), packages: packages)
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

        // MARK: - Mapping (the adapter's translation; pure and unit-testable)

        /// `[name: count]` from the contract into `Model.Framework`, ordered by document
        /// count then name, since the engine returns an unordered map and the sidebar
        /// wants a stable order.
        static func frameworks(from counts: [String: Int]) -> [Model.Framework] {
            counts
                .map { Model.Framework(id: $0.key, name: $0.key, documentCount: $0.value) }
                .sorted {
                    $0.documentCount != $1.documentCount
                        ? $0.documentCount > $1.documentCount
                        : $0.name < $1.name
                }
        }

        /// A rendered-markdown document into `Model.DocPage`. The contract returns only
        /// the rendered string, so the title is taken from the first `#` heading (falling
        /// back to the URI) and the source from the URI scheme.
        static func page(uri: Model.DocURI, markdown: String) -> Model.DocPage {
            Model.DocPage(
                uri: uri,
                source: source(of: uri),
                title: title(fromMarkdown: markdown) ?? uri.rawValue,
                markdown: markdown,
            )
        }

        /// A `Search.Result` into a `Model.DocHit`, or nil when its URI is not a valid
        /// `Model.DocURI` (a malformed row is dropped rather than surfaced).
        ///
        /// `DocHit.availability` is left empty for now: the result's availability is a
        /// freeform string and `Model.Availability` is structured, so it is mapped only
        /// once the reader actually consumes it (an empty list, not a fabricated one).
        static func hit(from result: Search.Result) -> Model.DocHit? {
            guard let uri = Model.DocURI(result.uri) else { return nil }
            return Model.DocHit(
                id: result.id.uuidString,
                uri: uri,
                source: source(named: result.source),
                title: result.title,
                framework: result.framework.isEmpty ? nil : result.framework,
                snippet: result.cleanedSummary,
                score: result.score,
            )
        }

        /// A `samples` row into a `Model.SampleProject` (the unified bucket maps the
        /// doc-shaped result onto the sample shape; the real engine reads samples natively).
        static func sampleProject(from result: Search.Result) -> Model.SampleProject {
            Model.SampleProject(
                id: Model.SampleID(result.uri),
                title: result.title,
                summary: result.cleanedSummary,
                frameworks: result.framework.isEmpty ? [] : [result.framework],
            )
        }

        /// A `packages` row into a `Model.PackageHit`, parsing owner/repo/path from a
        /// `packages://owner/repo/path` URI.
        static func packageHit(from result: Search.Result) -> Model.PackageHit {
            let parts = result.uri
                .replacingOccurrences(of: "packages://", with: "")
                .split(separator: "/")
                .map(String.init)
            return Model.PackageHit(
                id: result.id.uuidString,
                owner: parts.first ?? "",
                repo: parts.count > 1 ? parts[1] : "",
                path: parts.count > 2 ? parts[2...].joined(separator: "/") : "",
                module: result.framework.isEmpty ? nil : result.framework,
                title: result.title,
                snippet: result.cleanedSummary,
                score: result.score,
            )
        }

        static func source(of uri: Model.DocURI) -> Model.Source {
            source(named: String(uri.rawValue.prefix { $0 != ":" }))
        }

        static func source(named scheme: String) -> Model.Source {
            Model.Source.allCases.first { $0.scheme == scheme } ?? .appleDocs
        }

        static func title(fromMarkdown markdown: String) -> String? {
            for raw in markdown.split(whereSeparator: \.isNewline) {
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("# ") {
                    return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                }
            }
            return nil
        }
    }
}
