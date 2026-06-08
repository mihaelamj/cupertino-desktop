import Foundation

public extension Catalog {
    /// Opaque handle to a downloaded or bundled Cupertino corpus.
    ///
    /// The handle identifies the corpus bundle as a whole. File names, schemas, and
    /// readers stay inside CupertinoDataEngine.
    struct CorpusHandle: Sendable, Hashable {
        public let bundleURL: URL

        public init(bundleURL: URL) {
            self.bundleURL = bundleURL
        }
    }
}
