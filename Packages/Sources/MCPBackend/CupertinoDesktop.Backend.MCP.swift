import DesktopCore
import DesktopModels

public extension CupertinoDesktop.Backend {
    /// The live adapter over the `cupertino serve` MCP subprocess: subprocess
    /// lifecycle, connection state, and string-to-model parsing. This is the
    /// only place the `cupertino` package is imported (wired in milestone M1).
    enum MCP {}
}
