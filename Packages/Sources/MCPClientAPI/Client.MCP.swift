public extension Client {
    /// The MCP client contract used by `Backend.LocalSubprocess`. Verbs return the server's
    /// text payload as a `String` (the conformer extracts it from MCP content
    /// blocks); the backend conformer parses that into `Model` types per
    /// docs/DESIGN.md section 6. Injecting `any Client.MCP` (not the concrete
    /// `MCPClient`) is what makes `Backend.LocalSubprocess` unit-testable with a fake.
    protocol MCP: Sendable {
        func connect() async throws
        func disconnect() async
        func callTool(_ name: String, arguments: [String: Client.Argument]) async throws -> String
        func readResource(_ uri: String) async throws -> String
    }
}
