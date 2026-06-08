import CupertinoDataKit
import Foundation

extension MobileBackend {
    /// A stand-in `Search.DocumentReading` driven by `MockCorpus.json`, a bundled file
    /// of real results captured from the cupertino index across every source (apple-docs,
    /// hig, swift-evolution, swift-org, swift-book, apple-archive, packages, samples):
    /// real framework names, real counts, real titles and abstracts, with availability
    /// metadata so the platform-minimum filters do real work. It lets the embedded
    /// backend and the shells run with life-like content when no local corpus is
    /// configured; production composition uses `MobileBackend.live(engine:)`.
    struct MockReader: Search.DocumentReading {
        private struct Corpus: Decodable {
            struct Framework: Decodable {
                let id: String
                let count: Int
            }

            struct Document: Decodable {
                let uri: String
                let source: String
                let framework: String
                let title: String
                let summary: String
                let markdown: String
                let availability: [String: String]?
            }

            let frameworks: [Framework]
            let documents: [Document]
        }

        private static let corpus: Corpus = {
            guard let url = Bundle.module.url(forResource: "MockCorpus", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(Corpus.self, from: data)
            else { return Corpus(frameworks: [], documents: []) }
            return decoded
        }()

        // Honors every option the captured corpus can answer: `source`,
        // `framework`, a free-text `query` over title/summary/body, the platform-minimum
        // floor (`minIOS`/`minMacOS`/.../`minSwift`, keeping rows available at or below
        // the threshold), and `limit`. `language` and `includeArchive` are accepted; the
        // archive source is selected through `source` rather than the flag here.
        // swiftlint:disable:next function_parameter_count
        func search(
            query: String, source: String?, framework: String?, language _: String?,
            limit: Int, includeArchive _: Bool,
            minIOS: String?, minMacOS: String?, minTvOS: String?,
            minWatchOS: String?, minVisionOS: String?, minSwift: String?,
        ) async throws -> [Search.Result] {
            var documents = Self.corpus.documents
            if let source, !source.isEmpty {
                documents = documents.filter { $0.source.caseInsensitiveCompare(source) == .orderedSame }
            }
            if let framework, !framework.isEmpty {
                documents = documents.filter { $0.framework.caseInsensitiveCompare(framework) == .orderedSame }
            }
            if !query.isEmpty {
                documents = documents.filter {
                    $0.title.localizedCaseInsensitiveContains(query)
                        || $0.summary.localizedCaseInsensitiveContains(query)
                        || $0.markdown.localizedCaseInsensitiveContains(query)
                }
            }
            let floor: [String: String?] = [
                "iOS": minIOS, "macOS": minMacOS, "tvOS": minTvOS,
                "watchOS": minWatchOS, "visionOS": minVisionOS, "swift": minSwift,
            ]
            documents = documents.filter { Self.passesFloor($0.availability, floor: floor) }

            return documents.prefix(max(0, limit)).map { document in
                Search.Result(
                    uri: document.uri,
                    source: document.source,
                    framework: document.framework,
                    title: document.title,
                    summary: document.summary,
                    filePath: "",
                    wordCount: document.markdown.split(whereSeparator: \.isWhitespace).count,
                    rank: -1,
                )
            }
        }

        func getDocumentContent(uri: String, format _: Search.DocumentFormat) async throws -> String? {
            Self.corpus.documents.first { $0.uri == uri }?.markdown
        }

        func listFrameworks() async throws -> [String: Int] {
            Dictionary(Self.corpus.frameworks.map { ($0.id, $0.count) }, uniquingKeysWith: { first, _ in first })
        }

        func documentCount() async throws -> Int {
            Self.corpus.documents.count
        }

        func disconnect() async {}

        /// A document passes when, for every platform whose minimum is set, it carries an
        /// availability for that platform at or below the threshold (rows that lack the
        /// platform are excluded once a minimum for it is requested).
        private static func passesFloor(_ availability: [String: String]?, floor: [String: String?]) -> Bool {
            for (platform, minimum) in floor {
                guard let minimum, !minimum.isEmpty else { continue }
                guard let value = availability?[platform], versionAtMost(value, minimum) else { return false }
            }
            return true
        }

        /// `lhs <= rhs` for dotted-decimal version strings (`"13.0" <= "17.0"`).
        private static func versionAtMost(_ lhs: String, _ rhs: String) -> Bool {
            let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
            let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
            for index in 0 ..< max(left.count, right.count) {
                let leftValue = index < left.count ? left[index] : 0
                let rightValue = index < right.count ? right[index] : 0
                if leftValue != rightValue { return leftValue < rightValue }
            }
            return true
        }
    }
}
