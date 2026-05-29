import AppModels
import BackendAPI
import LocalSubprocessBackend
@testable import MacBackendImpl
import MCPClientAPI
import Testing

@Suite("Backend seam scaffold")
struct BackendScaffoldTests {
    @Test("MacBackend.live() composes an opaque DocumentationBackend")
    func liveComposes() async {
        // The composition root returns the seam type, not a concrete: callers
        // cannot tell it is MCP-over-subprocess (enforced at compile time by the
        // `any Backend.Documentation` annotation). This is the contract that lets
        // iOS swap in the embedded backend later with no change above the seam. At
        // M0 the subprocess transport is unimplemented, so connecting fails
        // honestly rather than pretending the backend is up.
        let backend: any Backend.Documentation = MacBackend.live()
        await #expect(throws: (any Error).self) {
            try await backend.connect()
        }
    }

    @Test("Unimplemented calls fail honestly rather than returning fake data")
    func unimplementedThrows() async {
        let backend = MacBackend.live()
        await #expect(throws: (any Error).self) {
            _ = try await backend.listFrameworks()
        }
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

    @Test("Value types carry their fields")
    func modelsHoldData() {
        let framework = Model.Framework(id: "swiftui", name: "SwiftUI", documentCount: 42)
        #expect(framework.id == "swiftui")
        #expect(framework.documentCount == 42)

        let uri = Model.DocURI("apple-docs://swiftui/view")
        #expect(uri.rawValue == "apple-docs://swiftui/view")
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
