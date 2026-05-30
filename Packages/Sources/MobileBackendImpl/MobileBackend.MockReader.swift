import CupertinoDataKit
import Foundation

extension MobileBackend {
    /// A stand-in `Search.DocumentReading` driven by `MockCorpus.json`, a bundled file
    /// of real results captured from the cupertino index (real framework names, real
    /// document counts, real Apple abstracts). It lets the embedded backend and the
    /// shared shells run on iPhone/iPad with life-like content before the real
    /// `CupertinoDataEngine` ships; swap to `MobileBackend.live(dataSource:)` over the
    /// real engine when it lands and this is retired.
    struct MockReader: Search.DocumentReading {
        private struct Corpus: Decodable {
            struct Framework: Decodable {
                let id: String
                let count: Int
            }

            struct Document: Decodable {
                let uri: String
                let framework: String
                let title: String
                let summary: String
                let markdown: String
            }

            let frameworks: [Framework]
            let documents: [Document]
        }

        /// Decoded once from the bundled fixture. An empty corpus on failure keeps the
        /// app running (an empty sidebar) rather than crashing.
        private static let corpus: Corpus = {
            guard let url = Bundle.module.url(forResource: "MockCorpus", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(Corpus.self, from: data)
            else { return Corpus(frameworks: [], documents: []) }
            return decoded
        }()

        // Honors the contract's filters that the captured corpus can answer: `source`
        // (only `apple-docs` here), `framework`, a free-text `query` over title/summary/
        // body, and `limit`. Platform-minimum and language filters are accepted and
        // ignored, since the captured rows carry no availability metadata.
        // swiftlint:disable:next function_parameter_count
        func search(
            query: String, source: String?, framework: String?, language _: String?,
            limit: Int, includeArchive _: Bool,
            minIOS _: String?, minMacOS _: String?, minTvOS _: String?,
            minWatchOS _: String?, minVisionOS _: String?, minSwift _: String?,
        ) async throws -> [Search.Result] {
            if let source, !source.isEmpty, source.caseInsensitiveCompare("apple-docs") != .orderedSame {
                return []
            }
            var documents = Self.corpus.documents
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
            return documents.prefix(max(0, limit)).map { document in
                Search.Result(
                    uri: document.uri,
                    source: "apple-docs",
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
    }
}
