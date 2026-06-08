import CatalogStoreAPI
import Foundation

public extension Catalog.DevelopmentStore {
    /// Failures from resolving a local development catalog.
    enum Error: LocalizedError, Sendable, Equatable {
        case missingCorpusDirectory(path: String)

        public var errorDescription: String? {
            switch self {
            case let .missingCorpusDirectory(path):
                "Development catalog directory does not exist: \(path)"
            }
        }

        public var recoverySuggestion: String? {
            switch self {
            case .missingCorpusDirectory:
                "Install the Cupertino catalog locally, or set CUPERTINO_MOBILE_DEV_CATALOG to a valid catalog directory."
            }
        }
    }
}
