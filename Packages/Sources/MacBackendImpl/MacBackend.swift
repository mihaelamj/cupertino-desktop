import BackendAPI
import CupertinoMCPClient
import CupertinoMCPClientAPI
import CupertinoMCPSubprocessTransport
import CupertinoMCPTransport
import LocalSubprocessBackend

/// Composition root for the macOS backend: the one place the concrete MCP
/// conformer, the client, and the subprocess transport are wired together.
/// App targets depend on this and get back an opaque `any Backend.Documentation`,
/// so nothing in the app or features knows it is MCP-over-subprocess.
public enum MacBackend {
    /// Build the live macOS backend: MCP over a `cupertino serve` subprocess.
    /// - Parameter executable: the cupertino binary name or absolute path.
    public static func live(executable: String = "cupertino") -> any Backend.Documentation {
        let transport = Transport.Subprocess(command: executable, arguments: ["serve"])
        let client = MCPClient(transport: transport)
        return Backend.LocalSubprocess(client: client)
    }
}
