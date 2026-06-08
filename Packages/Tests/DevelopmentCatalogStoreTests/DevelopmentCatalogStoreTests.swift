import CatalogStoreAPI
@testable import DevelopmentCatalogStore
import Foundation
import Testing

@Suite("Development catalog store")
struct DevelopmentCatalogStoreTests {
    @Test("returns an opaque corpus handle for an existing directory")
    func existingDirectoryReturnsHandle() async throws {
        let root = try Self.makeTemporaryDirectory()
        let store = Catalog.DevelopmentStore(corpusURL: root)

        let handle = try await store.currentCorpus()

        #expect(handle == Catalog.CorpusHandle(bundleURL: root))
    }

    @Test("rejects missing directories before the engine sees a handle")
    func missingDirectoryThrows() async throws {
        let root = try Self.makeTemporaryDirectory().appendingPathComponent("missing", isDirectory: true)
        let store = Catalog.DevelopmentStore(corpusURL: root)

        await #expect(throws: Catalog.DevelopmentStore.Error.missingCorpusDirectory(path: root.path)) {
            _ = try await store.currentCorpus()
        }
    }

    @Test("environment path wins over home fallback")
    func environmentPathWins() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
        let url = Catalog.DevelopmentStore.corpusURL(
            environment: [Catalog.DevelopmentStore.catalogPathEnvironmentKey: "/tmp/catalog"],
            homeDirectory: home,
        )

        #expect(url.path == "/tmp/catalog")
    }

    @Test("legacy embedded path remains accepted for package smoke scripts")
    func legacyEnvironmentPathRemainsAccepted() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
        let url = Catalog.DevelopmentStore.corpusURL(
            environment: [Catalog.DevelopmentStore.legacyCatalogPathEnvironmentKey: "/tmp/legacy-catalog"],
            homeDirectory: home,
        )

        #expect(url.path == "/tmp/legacy-catalog")
    }

    @Test("home fallback uses dot cupertino")
    func homeFallbackUsesDotCupertino() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
        let url = Catalog.DevelopmentStore.corpusURL(environment: [:], homeDirectory: home)

        #expect(url.path == "/Users/example/.cupertino")
    }

    @Test("catalog install states cover the mobile lifecycle")
    func installStatesCoverLifecycle() {
        #expect(Catalog.InstallState.allCases == [
            .notInstalled,
            .downloading,
            .verifying,
            .installing,
            .ready,
            .updateAvailable,
            .failed,
            .removing,
        ])
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("development-catalog-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
