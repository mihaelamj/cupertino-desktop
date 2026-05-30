import AppModels
import BackendAPI
import Foundation
import SwiftMCPClientAPI

/// Parsing and argument-building for the subprocess adapter, split out of
/// `Backend.LocalSubprocess` so the actor stays focused on the protocol verbs. These
/// turn `AppModels` queries into `search`/`read_document` arguments and the server's
/// ranked markdown back into `AppModels`. Helpers reached from the actor file are
/// internal; the rest stay private to this file.
extension Backend.LocalSubprocess {
    // MARK: Argument building

    /// Doc-like sources (everything except `samples` and `packages`, which carry a
    /// different result nature). `searchDocs` narrows the selection to these.
    static let docLikeSources: Set<Model.Source> = [
        .appleDocs, .appleArchive, .hig, .swiftEvolution, .swiftOrg, .swiftBook,
    ]

    static func searchArguments(_ query: Model.DocsQuery, source: Model.Source) -> [String: Client.Argument] {
        var arguments: [String: Client.Argument] = [
            "query": .string(query.text),
            "source": .string(source.scheme),
            "limit": .int(min(100, max(1, query.limit))),
        ]
        if let framework = query.framework, !framework.isEmpty { arguments["framework"] = .string(framework) }
        if let language = query.language, !language.isEmpty { arguments["language"] = .string(language) }
        applyFloor(query.floor, to: &arguments)
        return arguments
    }

    static func unifiedArguments(_ query: Model.UnifiedQuery) -> [String: Client.Argument] {
        var arguments: [String: Client.Argument] = [
            "query": .string(query.text),
            "limit": .int(min(100, max(1, query.limitPerSource))),
            "include_archive": .bool(true),
        ]
        if let framework = query.framework, !framework.isEmpty { arguments["framework"] = .string(framework) }
        applyFloor(query.floor, to: &arguments)
        return arguments
    }

    private static func applyFloor(_ floor: Model.PlatformFloor, to arguments: inout [String: Client.Argument]) {
        if let value = floor.iOS { arguments["min_ios"] = .string(value) }
        if let value = floor.macOS { arguments["min_macos"] = .string(value) }
        if let value = floor.tvOS { arguments["min_tvos"] = .string(value) }
        if let value = floor.watchOS { arguments["min_watchos"] = .string(value) }
        if let value = floor.visionOS { arguments["min_visionos"] = .string(value) }
        if let value = floor.swift { arguments["min_swift"] = .string(value) }
    }

    // MARK: Source mapping

    static func source(of uri: Model.DocURI) -> Model.Source {
        guard let separator = uri.rawValue.range(of: "://") else { return .appleDocs }
        let scheme = String(uri.rawValue[..<separator.lowerBound])
        return Model.Source.allCases.first { $0.scheme == scheme } ?? .appleDocs
    }

    // MARK: read_document decoding

    struct RawDocument: Decodable {
        let title: String?
        let abstract: String?
        let rawMarkdown: String?
        let declaration: RawDeclaration?
        let sections: [RawSection]?

        struct RawDeclaration: Decodable {
            let code: String
            let language: String?
        }

        struct RawSection: Decodable {
            let title: String
            let content: String
        }
    }

    // MARK: Per-source ranked-list parsing (searchDocs)

    /// Parse the per-source `search` markdown into `DocHit`s. Each result is a block
    /// that starts at a `## <n>. <title>` heading, carries `**URI:**`/`**Framework:**`/
    /// `**Score:**` bullets, then a snippet paragraph, and ends at a `---` rule. The
    /// trailing "Other sources" footer has no numbered heading, so it is ignored.
    static func parseDocHits(_ markdown: String) -> [Model.DocHit] {
        var hits: [Model.DocHit] = []
        var current: PartialHit?

        func finalize() {
            if let partial = current, let hit = partial.makeHit() { hits.append(hit) }
            current = nil
        }

        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if let title = numberedHeadingTitle(line) {
                finalize()
                current = PartialHit(title: title)
            } else if line.trimmingCharacters(in: .whitespaces) == "---" {
                finalize()
            } else if current != nil {
                if let uri = backticked(line, after: "**URI:**") {
                    current?.uri = uri
                } else if let framework = backticked(line, after: "**Framework:**") {
                    current?.framework = framework
                } else if let score = plainValue(line, after: "**Score:**") {
                    current?.score = Double(score)
                } else if !line.hasPrefix("- **"), !line.hasPrefix("#") {
                    let text = stripBold(line).trimmingCharacters(in: .whitespaces)
                    if !text.isEmpty { current?.appendSnippet(text) }
                }
            }
        }
        finalize()
        return hits
    }

    private struct PartialHit {
        let title: String
        var uri: String?
        var framework: String?
        var score: Double?
        var snippet = ""

        mutating func appendSnippet(_ text: String) {
            snippet += snippet.isEmpty ? text : " " + text
        }

        func makeHit() -> Model.DocHit? {
            guard let uri, let docURI = Model.DocURI(uri) else { return nil }
            return Model.DocHit(
                id: uri,
                uri: docURI,
                source: Backend.LocalSubprocess.source(of: docURI),
                title: title,
                framework: framework,
                snippet: snippet,
                score: score ?? 0,
            )
        }
    }

    // MARK: Unified parsing (searchEverything)

    /// Parse the no-source `search` markdown, whose results come grouped under
    /// per-source section headers (`## 📚 Apple Documentation (3)`), into the doc,
    /// sample, and package buckets. Each item is a `- **Title**` bullet followed by
    /// indented `URI:`/`ID:`/`Frameworks:` sub-bullets and a snippet sub-bullet.
    static func parseUnified(_ markdown: String) -> Model.UnifiedResults {
        var docs: [Model.DocHit] = []
        var projects: [Model.SampleProject] = []
        var packages: [Model.PackageHit] = []

        var section: Model.Source?
        var item: PartialItem?

        func finalize() {
            defer { item = nil }
            guard let item, let section else { return }
            switch section {
            case .samples:
                if let project = item.makeProject() { projects.append(project) }
            case .packages:
                if let package = item.makePackage() { packages.append(package) }
            default:
                if let hit = item.makeDocHit(source: section) { docs.append(hit) }
            }
        }

        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if let heading = sectionSource(line) {
                finalize()
                section = heading
            } else if let title = itemTitle(line) {
                finalize()
                item = PartialItem(title: title)
            } else if item != nil {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if let uri = backticked(trimmed, after: "URI:") {
                    item?.uri = uri
                } else if let id = backticked(trimmed, after: "ID:") {
                    item?.sampleID = id
                } else if let frameworks = plainValue(trimmed, after: "Frameworks:") {
                    item?.frameworks = frameworks
                } else if trimmed.hasPrefix("- "), !trimmed.hasPrefix("- Availability:"), !trimmed.hasPrefix("- Symbols:") {
                    let text = stripBold(String(trimmed.dropFirst(2))).trimmingCharacters(in: CharacterSet(charactersIn: "> "))
                    if !text.isEmpty, item?.snippet.isEmpty == true { item?.snippet = text }
                }
            }
        }
        finalize()
        return Model.UnifiedResults(docs: docs, samples: Model.SampleResults(projects: projects, files: []), packages: packages)
    }

    private struct PartialItem {
        let title: String
        var uri: String?
        var sampleID: String?
        var frameworks: String?
        var snippet = ""

        func makeDocHit(source: Model.Source) -> Model.DocHit? {
            guard let uri, let docURI = Model.DocURI(uri) else { return nil }
            return Model.DocHit(
                id: uri, uri: docURI, source: source, title: title,
                framework: nil, snippet: snippet, score: 0,
            )
        }

        func makeProject() -> Model.SampleProject? {
            guard let sampleID else { return nil }
            let names = (frameworks ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            return Model.SampleProject(id: Model.SampleID(sampleID), title: title, summary: snippet, frameworks: names)
        }

        func makePackage() -> Model.PackageHit? {
            guard let uri, let docURI = Model.DocURI(uri),
                  let separator = docURI.rawValue.range(of: "://") else { return nil }
            let components = docURI.rawValue[separator.upperBound...].split(separator: "/").map(String.init)
            guard components.count >= 2 else { return nil }
            return Model.PackageHit(
                id: uri,
                owner: components[0],
                repo: components[1],
                path: components.dropFirst(2).joined(separator: "/"),
                module: nil,
                title: title,
                snippet: snippet,
                score: 0,
            )
        }
    }

    // MARK: Line helpers

    private static func numberedHeadingTitle(_ line: String) -> String? {
        guard line.hasPrefix("## ") else { return nil }
        let rest = line.dropFirst(3)
        guard let dot = rest.firstIndex(of: "."), rest[..<dot].allSatisfy(\.isNumber), !rest[..<dot].isEmpty else { return nil }
        return rest[rest.index(after: dot)...].trimmingCharacters(in: .whitespaces)
    }

    private static func sectionSource(_ line: String) -> Model.Source? {
        guard line.hasPrefix("## "), line.contains("(") else { return nil }
        if line.contains("Apple Documentation") { return .appleDocs }
        if line.contains("Apple Archive") { return .appleArchive }
        if line.contains("Sample Code") { return .samples }
        if line.contains("Human Interface Guidelines") { return .hig }
        if line.contains("Swift Evolution") { return .swiftEvolution }
        if line.contains("Swift Packages") || line.contains("Swift Package") { return .packages }
        if line.contains("Swift Book") { return .swiftBook }
        if line.contains("Swift.org") { return .swiftOrg }
        return nil
    }

    private static func itemTitle(_ line: String) -> String? {
        guard line.hasPrefix("- **"), line.hasSuffix("**"), line.count > 6 else { return nil }
        return String(line.dropFirst(4).dropLast(2))
    }

    /// Extract a backticked value following a label, e.g. ``- **URI:** `apple-docs://x` `` → `apple-docs://x`.
    private static func backticked(_ line: String, after label: String) -> String? {
        guard let labelRange = line.range(of: label) else { return nil }
        let rest = line[labelRange.upperBound...]
        guard let open = rest.firstIndex(of: "`") else { return nil }
        let afterOpen = rest.index(after: open)
        guard let close = rest[afterOpen...].firstIndex(of: "`") else { return nil }
        return String(rest[afterOpen ..< close])
    }

    /// Extract a plain (non-backticked) value following a label on the same line.
    private static func plainValue(_ line: String, after label: String) -> String? {
        guard let labelRange = line.range(of: label) else { return nil }
        let value = line[labelRange.upperBound...].trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    private static func stripBold(_ line: String) -> String {
        line.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "<b>", with: "")
            .replacingOccurrences(of: "</b>", with: "")
    }
}
