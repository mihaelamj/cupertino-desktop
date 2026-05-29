public extension Client {
    /// A typed MCP tool argument. Our own value type so the client seam carries no
    /// MCPCore/AnyCodable detail; the conformer maps these to the wire encoding.
    enum Argument: Sendable, Hashable {
        case string(String)
        case int(Int)
        case bool(Bool)
    }
}
