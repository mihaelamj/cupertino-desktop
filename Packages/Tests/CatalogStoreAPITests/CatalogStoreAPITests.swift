@testable import CatalogStoreAPI
import Foundation
import Testing

@Suite("CatalogStore API")
struct CatalogStoreAPITests {
    @Test("Corpus handles carry only the installed catalog URL")
    func corpusHandleCarriesBundleURL() {
        let bundleURL = URL(fileURLWithPath: "/tmp/cupertino-corpus", isDirectory: true)
        let handle = Catalog.CorpusHandle(bundleURL: bundleURL)
        #expect(handle.bundleURL == bundleURL)
    }

    @Test("Catalog stores are async seams")
    func storeReturnsCurrentCorpusHandle() async throws {
        let bundleURL = URL(fileURLWithPath: "/tmp/cupertino-current-corpus", isDirectory: true)
        let store = FixedCatalogStore(handle: Catalog.CorpusHandle(bundleURL: bundleURL))
        #expect(try await store.currentCorpus() == Catalog.CorpusHandle(bundleURL: bundleURL))
    }
}

private struct FixedCatalogStore: Catalog.Store {
    let handle: Catalog.CorpusHandle

    func currentCorpus() async throws -> Catalog.CorpusHandle {
        handle
    }
}
