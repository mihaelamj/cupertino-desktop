import AppModels
import BackendAPI
import Foundation
@testable import LocalSubprocessBackend
import SwiftMCPClient
import SwiftMCPClientAPI
import SwiftMCPSubprocessTransport
import SwiftMCPTransport
import Testing

@Suite("LocalSubprocess adapter")
struct LocalSubprocessBackendTests {
    /// Hermetic: a fake `Client.MCP` returns the real `list_frameworks` markdown shape;
    /// the adapter parses it into `Model.Framework`. No process, no MCP wire.
    @Test("listFrameworks parses the markdown table")
    func parsesFrameworks() async throws {
        let markdown = """
        # Available Frameworks

        Total documents: **352712**

        | Framework | Documents |
        |-----------|----------:|
        | `swiftui` | 8679 |
        | `foundation` | 13,649 |
        """
        let backend = Backend.LocalSubprocess(client: StubClient(toolText: markdown))
        let frameworks = try await backend.listFrameworks()

        #expect(frameworks.count == 2)
        let swiftui = frameworks.first { $0.id == "swiftui" }
        #expect(swiftui?.documentCount == 8679)
        // Comma-grouped counts parse too.
        #expect(frameworks.first { $0.id == "foundation" }?.documentCount == 13649)
        // Header and separator rows are skipped.
        #expect(!frameworks.contains { $0.id == "Framework" })
    }

    @Test("the parser ignores non-table noise")
    func parserIgnoresNoise() {
        let frameworks = Backend.LocalSubprocess.parseFrameworks("no table here\njust prose")
        #expect(frameworks.isEmpty)
    }

    /// Opt-in integration test against the installed `cupertino` binary. Enable with
    /// `CUPERTINO_INTEGRATION=1 swift test`. Time-limited so a stuck server cannot hang.
    @Test(
        "listFrameworks returns live data from the cupertino binary",
        .enabled(if: ProcessInfo.processInfo.environment["CUPERTINO_INTEGRATION"] == "1"),
        .timeLimit(.minutes(1)),
    )
    func liveListFrameworks() async throws {
        let transport = Transport.Subprocess(command: "cupertino", arguments: ["serve"])
        let backend = Backend.LocalSubprocess(client: MCPClient(transport: transport))
        try await backend.connect()
        defer { Task { await backend.disconnect() } }

        let frameworks = try await backend.listFrameworks()
        #expect(!frameworks.isEmpty)
        #expect(frameworks.contains { $0.id == "swiftui" })
    }
}

/// A `Client.MCP` double that returns canned tool text. Possible only because the
/// adapter depends on the `Client.MCP` protocol, not the concrete client.
private actor StubClient: Client.MCP {
    let toolText: String
    init(toolText: String) {
        self.toolText = toolText
    }

    func connect() async throws {}
    func disconnect() async {}
    func callTool(_: String, arguments _: [String: Client.Argument]) async throws -> String {
        toolText
    }

    func readResource(_: String) async throws -> String {
        toolText
    }
}
