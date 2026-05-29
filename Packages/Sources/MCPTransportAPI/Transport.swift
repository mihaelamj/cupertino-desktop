/// Transport seam for the MCP conformer. This is NOT a universal layer: only
/// `Backend.MCP` (via `MCPClient`) speaks over a `Transport.Channel`. The
/// embedded backend reaches cupertino directly and never touches this.
/// Adding a remote transport later means one new `Transport.Channel` conformer.
public enum Transport {}
