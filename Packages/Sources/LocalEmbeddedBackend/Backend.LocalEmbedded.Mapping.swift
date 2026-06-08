import AppModels
import BackendAPI
import CupertinoDataKit
import Foundation

extension Backend.LocalEmbedded {
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

    static func sampleProject(from project: Sample.Index.Project, filePaths: [String] = []) -> Model.SampleProject {
        Model.SampleProject(
            id: Model.SampleID(project.id),
            title: project.title,
            summary: project.description,
            frameworks: project.frameworks,
            readme: project.readme,
            webURL: project.webURL.isEmpty ? nil : project.webURL,
            filePaths: filePaths,
            fileCount: project.fileCount,
            deploymentTargets: deploymentTargets(from: project.deploymentTargets),
        )
    }

    static func sampleFile(from file: Sample.Index.File) -> Model.SampleFile {
        Model.SampleFile(
            projectID: Model.SampleID(file.projectId),
            path: file.path,
            filename: file.filename,
            language: file.fileExtension.isEmpty ? nil : file.fileExtension,
            contents: file.content,
        )
    }

    static func sampleFileHit(from result: Sample.Index.FileSearchResult) -> Model.SampleFileHit {
        Model.SampleFileHit(
            id: "\(result.projectId)|\(result.path)",
            projectID: Model.SampleID(result.projectId),
            path: result.path,
            filename: result.filename,
            snippet: result.snippet,
            score: -result.rank,
        )
    }

    /// `Sample.Index.Reader.searchProjects` accepts all OS floors, while
    /// `searchFiles` still accepts the legacy single platform/min-version pair.
    /// The adapter passes the first requested OS floor to file search and leaves
    /// any richer future filtering to the Cupertino-owned reader contract.
    static func sampleFileFloor(from floor: Model.PlatformFloor) -> (platform: String, minVersion: String)? {
        if let version = floor.iOS { return ("iOS", version) }
        if let version = floor.macOS { return ("macOS", version) }
        if let version = floor.tvOS { return ("tvOS", version) }
        if let version = floor.watchOS { return ("watchOS", version) }
        if let version = floor.visionOS { return ("visionOS", version) }
        return nil
    }

    /// Package search currently accepts one platform floor plus an orthogonal
    /// swift-tools-version filter. Preserve the UI model's platform precedence at the
    /// adapter boundary and leave richer filtering to the Cupertino-owned contract.
    static func packageAvailability(from floor: Model.PlatformFloor) -> Search.AvailabilityFilter? {
        if let version = floor.iOS { return Search.AvailabilityFilter(platform: "iOS", minVersion: version) }
        if let version = floor.macOS { return Search.AvailabilityFilter(platform: "macOS", minVersion: version) }
        if let version = floor.tvOS { return Search.AvailabilityFilter(platform: "tvOS", minVersion: version) }
        if let version = floor.watchOS { return Search.AvailabilityFilter(platform: "watchOS", minVersion: version) }
        if let version = floor.visionOS { return Search.AvailabilityFilter(platform: "visionOS", minVersion: version) }
        return nil
    }

    static func packageSwiftTools(from floor: Model.PlatformFloor) -> Search.SwiftToolsFilter? {
        floor.swift.map { Search.SwiftToolsFilter(minVersion: $0) }
    }

    static func packageHits(
        from searcher: any Search.PackagesSearcher,
        text: String,
        limit: Int,
        floor: Model.PlatformFloor,
        appleImport: String?,
    ) async throws -> [Model.PackageHit] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        let results = try await searcher.searchPackages(
            query: text,
            limit: limit,
            availability: packageAvailability(from: floor),
            swiftTools: packageSwiftTools(from: floor),
            appleImport: appleImport,
        )
        return results.map(Self.packageHit(from:))
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

    static func samePackage(_ lhs: Model.PackageHit, _ rhs: Model.PackageHit) -> Bool {
        lhs.owner == rhs.owner && lhs.repo == rhs.repo && lhs.path == rhs.path
    }

    static func symbolHits(
        from results: [Search.SymbolSearchResult],
        floor: Model.PlatformFloor,
        using reader: any Search.SymbolReading,
    ) async throws -> [Model.SymbolHit] {
        let hits = results.compactMap(Self.symbolHit(from:))
        guard Self.hasOSFloor(floor) else { return hits }
        let minima = try await reader.fetchPlatformMinima(uris: hits.map(\.docURI.rawValue))
        return hits.filter {
            Search.PlatformFilter.passes(
                minima: minima[$0.docURI.rawValue],
                minIOS: floor.iOS,
                minMacOS: floor.macOS,
                minTvOS: floor.tvOS,
                minWatchOS: floor.watchOS,
                minVisionOS: floor.visionOS,
            )
        }
    }

    static func symbolHit(from result: Search.SymbolSearchResult) -> Model.SymbolHit? {
        guard let uri = Model.DocURI(result.docUri) else { return nil }
        return Model.SymbolHit(
            id: "\(result.docUri)#\(result.symbolName)#\(result.symbolKind)",
            docURI: uri,
            docTitle: result.docTitle,
            framework: result.framework,
            name: result.symbolName,
            kind: symbolKind(from: result.symbolKind),
            signature: result.signature,
            attributes: splitList(result.attributes),
            conformances: splitList(result.conformances),
            genericParams: result.genericParams,
            isAsync: result.isAsync,
            isPublic: result.isPublic,
        )
    }

    static func inheritanceTree(from tree: Search.InheritanceTree) -> Model.InheritanceTree? {
        guard let startURI = Model.DocURI(tree.startURI) else { return nil }
        return Model.InheritanceTree(
            startURI: startURI,
            ancestors: tree.ancestors.compactMap(Self.inheritanceNode(from:)),
            descendants: tree.descendants.compactMap(Self.inheritanceNode(from:)),
        )
    }

    static func inheritanceNode(from node: Search.InheritanceNode) -> Model.InheritanceTree.Node? {
        guard let uri = Model.DocURI(node.uri) else { return nil }
        return Model.InheritanceTree.Node(
            uri: uri,
            title: title(fromURI: node.uri),
            children: node.children.compactMap(Self.inheritanceNode(from:)),
        )
    }

    static func inheritanceCandidate(from candidates: [Search.InheritanceCandidate], framework: String?) -> Search.InheritanceCandidate? {
        guard let framework, !framework.isEmpty else {
            return candidates.first
        }
        return candidates.first { $0.framework.caseInsensitiveCompare(framework) == .orderedSame }
    }

    static func backendInheritanceDirection(from direction: Model.InheritanceDirection) -> Search.InheritanceDirection {
        switch direction {
        case .ancestors:
            .up
        case .descendants:
            .down
        case .both:
            .both
        }
    }

    static func backendConcurrencyPattern(from pattern: Model.ConcurrencyPattern) -> String {
        backendConcurrencyPatterns[pattern] ?? pattern.rawValue
    }

    static func backendKind(from kind: Model.SymbolKind?) -> String? {
        kind.flatMap { backendKinds[$0] }
    }

    static func symbolKind(from rawKind: String) -> Model.SymbolKind {
        symbolKinds[rawKind.lowercased()] ?? .unknown
    }

    static func splitList(_ value: String?) -> [String] {
        value?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
    }

    static func deploymentTargets(from raw: [String: String]) -> [Model.Availability.Platform: String] {
        Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
            guard let platform = availabilityPlatforms[key.lowercased()] else { return nil }
            return (platform, value)
        })
    }

    static func hasOSFloor(_ floor: Model.PlatformFloor) -> Bool {
        floor.iOS != nil || floor.macOS != nil || floor.tvOS != nil || floor.watchOS != nil || floor.visionOS != nil
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

    static func title(fromURI uri: String) -> String {
        let last = uri.split(separator: "/").last.map(String.init) ?? uri
        return last.removingPercentEncoding ?? last
    }
}

private let backendConcurrencyPatterns: [Model.ConcurrencyPattern: String] = [
    .mainActor: "mainactor",
    .asyncSequence: "asyncsequence",
]

private let backendKinds: [Model.SymbolKind: String] = [
    .structure: "struct",
    .classType: "class",
    .actorType: "actor",
    .enumeration: "enum",
    .protocolType: "protocol",
    .function: "function",
    .property: "property",
    .method: "method",
    .initializer: "initializer",
    .subscriptType: "subscript",
    .operatorType: "operator",
    .typeAlias: "typealias",
    .macro: "macro",
    .enumCase: "case",
    .article: "article",
    .framework: "framework",
]

private let symbolKinds: [String: Model.SymbolKind] = [
    "struct": .structure,
    "class": .classType,
    "actor": .actorType,
    "enum": .enumeration,
    "protocol": .protocolType,
    "function": .function,
    "func": .function,
    "property": .property,
    "var": .property,
    "let": .property,
    "method": .method,
    "initializer": .initializer,
    "init": .initializer,
    "subscript": .subscriptType,
    "operator": .operatorType,
    "typealias": .typeAlias,
    "macro": .macro,
    "case": .enumCase,
    "enumcase": .enumCase,
    "enum-case": .enumCase,
    "article": .article,
    "framework": .framework,
]

private let availabilityPlatforms: [String: Model.Availability.Platform] = [
    "ios": .iOS,
    "macos": .macOS,
    "osx": .macOS,
    "mac": .macOS,
    "tvos": .tvOS,
    "watchos": .watchOS,
    "visionos": .visionOS,
]
