import MCPClientAPI
import TransportAPI

/// A transport-agnostic MCP client: speaks JSON-RPC (initialize / tools /
/// resources) over `any Transport.Channel`, reusing cupertino's `MCPCore`
/// protocol types verbatim on the wire. It conforms to `Client.MCP`, the
/// dependency-free seam `Backend.MCP` depends on, and translates between our
/// `Client.Argument`/`String` payloads and MCPCore's wire types at this boundary.
/// We deliberately do not build on cupertino's `MCP.Client`, which is
/// stdio-hardcoded with no transport injection point.
///
/// The request/response correlation, `initialize` handshake, per-request timeout,
/// and the MCPCore encode/decode land in milestone M1; this scaffold fixes the
/// shape and the transport wiring.
public actor MCPClient: Client.MCP {
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

    public func callTool(_: String, arguments _: [String: Client.Argument]) async throws -> String {
        // M1: encode an MCPCore `tools/call` request, send it over the transport,
        // await the response, and extract the text from its content blocks.
        throw Failure.notImplemented
    }

    public func readResource(_: String) async throws -> String {
        // M1: encode an MCPCore `resources/read` request and extract the text.
        throw Failure.notImplemented
    }

    /// Failures local to the client. Wire/transport errors surface as thrown
    /// `Transport.Channel` errors; backend-level mapping happens in `Backend.MCP`.
    public enum Failure: Error, Sendable {
        case notConnected
        case notImplemented
    }
}
