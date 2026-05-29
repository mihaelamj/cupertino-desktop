import Foundation
import MCPCore
import MCPTransportAPI

/// A transport-agnostic MCP client: speaks JSON-RPC (initialize / tools /
/// resources) over `any Transport.Channel`, reusing cupertino's `MCPCore`
/// protocol types verbatim. Used only by `Backend.MCP`. We deliberately do not
/// build on cupertino's `MCP.Client`, which is stdio-hardcoded with no
/// transport injection point.
///
/// The request/response correlation, `initialize` handshake, and per-request
/// timeout are implemented in milestone M1; this scaffold fixes the shape and
/// the transport wiring.
public actor MCPClient {
    private let transport: any Transport.Channel

    public init(transport: any Transport.Channel) {
        self.transport = transport
    }

    public func connect() async throws {
        try await transport.start()
        // M1: run the MCP `initialize` handshake and start consuming
        // `transport.inbound`, matching responses to pending requests by id.
    }

    public func disconnect() async {
        await transport.stop()
    }

    public func listTools() async throws -> [MCP.Core.Protocols.Tool] {
        throw Failure.notImplemented
    }

    public func callTool(
        name _: String,
        arguments _: [String: MCP.Core.Protocols.AnyCodable]? = nil,
    ) async throws -> MCP.Core.Protocols.CallToolResult {
        throw Failure.notImplemented
    }

    public func readResource(uri _: String) async throws -> MCP.Core.Protocols.ReadResourceResult {
        throw Failure.notImplemented
    }

    /// Failures local to the client. Wire/transport errors surface as thrown
    /// `Transport.Channel` errors; backend-level mapping happens in `Backend.MCP`.
    public enum Failure: Error, Sendable {
        case notConnected
        case notImplemented
    }
}
