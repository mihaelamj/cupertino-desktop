import BackendAPI
import LocalSubprocessBackend
import SwiftMCPClient
import SwiftMCPClientAPI
import SwiftMCPSubprocessTransport
import SwiftMCPTransport

/// Composition root for the macOS backend: the one place the concrete MCP
/// conformer, the client, and the subprocess transport are wired together.
/// App targets depend on this and get back an opaque `any Backend.Documentation`,
/// so nothing in the app or features knows it is MCP-over-subprocess.
public enum MacBackend {
    /// Build the live macOS backend: MCP over a `cupertino serve` subprocess.
    ///
    /// The executable is resolved to an absolute path first, so the subprocess launches
    /// regardless of the launching process's `PATH`. A GUI / `launchd` / XCUITest launch
    /// inherits only a minimal `PATH` that excludes Homebrew's bindir, so spawning the bare
    /// name `cupertino` (via `/usr/bin/env`) fails even when it is installed; an absolute
    /// path always works. When cupertino cannot be found, a `Backend.Unavailable` is returned
    /// so the UI shows an actionable "install cupertino" state instead of a generic failure.
    /// - Parameter executable: the cupertino binary name or absolute path.
    public static func live(executable: String = "cupertino") -> any Backend.Documentation {
        guard let resolved = CupertinoExecutable.resolve(name: executable) else {
            return Backend.Unavailable(failure: .executableMissing(name: executable, installHint: "brew install cupertino"))
        }
        let transport = Transport.Subprocess(command: resolved, arguments: ["serve"])
        let client = MCPClient(transport: transport)
        return Backend.LocalSubprocess(client: client)
    }
}
