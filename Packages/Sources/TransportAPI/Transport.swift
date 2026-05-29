/// Generic framed-byte transport seam: moves opaque frames between a client and
/// a server and carries no MCP, JSON-RPC, or cupertino types of its own (hence
/// the package is `TransportAPI`, not `MCP...`). It is not a universal backend
/// layer: today its only consumer is `Backend.MCP` (via `MCPClient`); the
/// embedded backend reaches cupertino directly and never touches this. A remote
/// transport later is one new `Transport.Channel` conformer, not a new package.
public enum Transport {}
