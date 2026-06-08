import AppModels
import BackendAPI
import CatalogStoreAPI
import CupertinoDataEngine
import Foundation
import LocalSubprocessBackend
@testable import MacBackendImpl
@testable import MobileBackendImpl
import SwiftMCPClientAPI
import Testing

@Suite("Backend seam scaffold")
struct BackendScaffoldTests {
    @Test("MacBackend.live() composes an opaque DocumentationBackend")
    func liveComposes() async {
        // The composition root returns the seam type, not a concrete: callers cannot
        // tell it is MCP-over-subprocess (enforced at compile time by the
        // `any Backend.Documentation` annotation). This is the contract that lets iOS
        // swap in the embedded adapter later with no change above the seam. We assert
        // a still-unimplemented verb fails honestly with our own `Failure` (no process
        // is spawned: the unimplemented verb throws before touching the transport).
        // Search and read are now implemented (docs/PROTOCOL.md section 4); sample
        // browsing is not, so it is the verb that exercises this contract here.
        let backend: any Backend.Documentation = MacBackend.live()
        await #expect(throws: Backend.Failure.self) {
            _ = try await backend.listSamples(framework: nil, limit: 10)
        }
    }

    @Test("Not-yet-implemented verbs fail honestly rather than returning fake data")
    func unimplementedThrows() async {
        let backend = MacBackend.live()
        await #expect(throws: Backend.Failure.self) {
            _ = try await backend.searchPackages(Model.PackageQuery(text: "swift"))
        }
    }

    @Test("MobileBackend.live(engine:) composes over the external data engine facade")
    func mobileLiveEngineComposes() async throws {
        let engine = CupertinoDataEngine()
        let backend: any Backend.Documentation = await MobileBackend.live(engine: engine)
        #expect(try await backend.listFrameworks().isEmpty)
        await backend.disconnect()
    }

    @Test("MobileBackend.live(catalogStore:) opens the opaque corpus handle through CupertinoDataEngine")
    func mobileLiveCatalogStoreUsesCorpusHandle() async throws {
        let missingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cupertino-missing-corpus-\(UInt64.random(in: 0 ..< .max))", isDirectory: true)
        let store = FixedCatalogStore(handle: Catalog.CorpusHandle(bundleURL: missingDirectory))

        await #expect(throws: CupertinoDataEngine.Error.missingCorpusDirectory(path: missingDirectory.path)) {
            _ = try await MobileBackend.live(catalogStore: store)
        }
    }

    @Test("MobileBackend.live(catalogStore:) propagates catalog resolution failures")
    func mobileLiveCatalogStorePropagatesStoreFailure() async throws {
        let store = FailingCatalogStore()

        await #expect(throws: CatalogFailure.unavailable) {
            _ = try await MobileBackend.live(catalogStore: store)
        }
    }

    /// Opt-in integration smoke against a real Cupertino corpus. Enable with
    /// `CUPERTINO_DESKTOP_EMBEDDED_INTEGRATION=1 swift test`, or run
    /// `../scripts/check-local-embedded-corpus.sh` from `Packages/`.
    @Test(
        "live LocalEmbeddedBackend real corpus smoke",
        .enabled(if: ProcessInfo.processInfo.environment["CUPERTINO_DESKTOP_EMBEDDED_INTEGRATION"] == "1"),
        .timeLimit(.minutes(2)),
    )
    func liveEmbeddedRealCorpusSmoke() async throws {
        let corpusURL = Self.embeddedCorpusURL()
        let store = FixedCatalogStore(handle: Catalog.CorpusHandle(bundleURL: corpusURL))
        let backend: any Backend.Documentation = try await MobileBackend.live(catalogStore: store)

        do {
            try await Self.assertLiveEmbeddedCorpus(backend)
            await backend.disconnect()
        } catch {
            await backend.disconnect()
            throw error
        }
    }

    private static func assertLiveEmbeddedCorpus(_ backend: any Backend.Documentation) async throws {
        let frameworks = try await backend.listFrameworks()
        #expect(frameworks.contains { $0.id == "swiftui" })

        let hits = try await backend.searchDocs(Model.DocsQuery(text: "View", sources: [.appleDocs], framework: "swiftui", limit: 5))
        let firstHit = try #require(hits.first)
        #expect(firstHit.uri.rawValue.hasPrefix("apple-docs://"))

        let page = try await backend.readDocument(firstHit.uri)
        #expect(page.source == .appleDocs)
        #expect(!page.markdown.isEmpty)

        let unified = try await backend.searchEverything(Model.UnifiedQuery(text: "View", limitPerSource: 3))
        #expect(!unified.docs.isEmpty || !unified.samples.projects.isEmpty || !unified.packages.isEmpty)

        let samples = try await backend.listSamples(framework: nil, limit: 1)
        #expect(!samples.isEmpty)

        let packages = try await backend.searchPackages(Model.PackageQuery(text: "swift", limit: 1))
        #expect(!packages.isEmpty)
    }

    @Test("Backend.LocalSubprocess is testable with a fake client (no real transport)")
    func backendTakesFakeClient() async throws {
        // The payoff of the Client.MCP seam: Backend.LocalSubprocess depends on the protocol,
        // so a fake client can be injected with no subprocess, no MCPCore, no
        // network. connect() forwards to the fake; verbs still fail honestly.
        let fake = FakeClient()
        let backend = Backend.LocalSubprocess(client: fake)
        try await backend.connect()
        #expect(await fake.didConnect)
        await #expect(throws: (any Error).self) {
            _ = try await backend.listFrameworks()
        }
    }

    @Test("Value types carry their fields and DocURI validates its scheme")
    func modelsHoldData() throws {
        let framework = Model.Framework(id: "swiftui", name: "SwiftUI", documentCount: 42)
        #expect(framework.id == "swiftui")
        #expect(framework.documentCount == 42)

        let uri = try #require(Model.DocURI("apple-docs://swiftui/view"))
        #expect(uri.rawValue == "apple-docs://swiftui/view")
        #expect(Model.DocURI("bogus-scheme://x") == nil) // unknown scheme rejected
        #expect(Model.DocURI("apple-docs://") == nil) // empty path rejected
    }

    private static func embeddedCorpusURL() -> URL {
        let path = ProcessInfo.processInfo.environment["CUPERTINO_DESKTOP_EMBEDDED_CORPUS"]
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? "~/.cupertino"
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
    }
}

/// A `Client.MCP` test double. Possible only because `Backend.LocalSubprocess` depends on the
/// `Client.MCP` protocol rather than the concrete `MCPClient`.
private actor FakeClient: Client.MCP {
    private(set) var didConnect = false

    func connect() async throws {
        didConnect = true
    }

    func disconnect() async {
        didConnect = false
    }

    func callTool(_: String, arguments _: [String: Client.Argument]) async throws -> String {
        throw Failure.unused
    }

    func readResource(_: String) async throws -> String {
        throw Failure.unused
    }

    enum Failure: Error { case unused }
}

private struct FixedCatalogStore: Catalog.Store {
    let handle: Catalog.CorpusHandle

    func currentCorpus() async throws -> Catalog.CorpusHandle {
        handle
    }
}

private struct FailingCatalogStore: Catalog.Store {
    func currentCorpus() async throws -> Catalog.CorpusHandle {
        throw CatalogFailure.unavailable
    }
}

private enum CatalogFailure: Error, Equatable {
    case unavailable
}
