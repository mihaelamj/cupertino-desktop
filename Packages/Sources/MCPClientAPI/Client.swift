/// Seam for the MCP client surface, expressed in our own types so this API stays
/// dependency-free (no MCPCore, no JSON-RPC, no cupertino). `Client.MCP` is the
/// protocol `Backend.LocalSubprocess` depends on; the concrete `MCPClient` (MCPClientKit)
/// conforms and translates to cupertino's MCPCore types at the boundary. This
/// keeps `LocalSubprocessBackend` importing only API packages and makes `Backend.LocalSubprocess`
/// testable with a fake client.
public enum Client {}
