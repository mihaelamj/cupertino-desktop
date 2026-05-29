/// The backend seam namespace. `Backend.Documentation` is the ONLY universal
/// contract features and UI depend on; how it is fulfilled (MCP over a
/// transport, or direct in-process cupertino calls) is a conformer detail that
/// never leaks above this protocol. See docs/DESIGN.md section 5.
public enum Backend {}
