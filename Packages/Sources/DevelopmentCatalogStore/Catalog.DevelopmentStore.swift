import CatalogStoreAPI
import Foundation

public extension Catalog {
    /// Development-only catalog store for mobile app work before the real installer lands.
    ///
    /// It resolves one caller-supplied catalog directory and returns an opaque
    /// `Catalog.CorpusHandle`. It deliberately does not inspect resource names, schema
    /// files, or SQLite details; CupertinoDataEngine owns that validation after the
    /// handle crosses the backend boundary.
    struct DevelopmentStore: Store {
        private let corpusURL: URL

        public init(corpusURL: URL) {
            self.corpusURL = corpusURL
        }

        public func currentCorpus() async throws -> CorpusHandle {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: corpusURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw Error.missingCorpusDirectory(path: corpusURL.path)
            }
            return CorpusHandle(bundleURL: corpusURL)
        }
    }
}
