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
    ///
    /// Spawned with `--no-reap`: by default `cupertino serve` reaps (SIGTERM/SIGKILL) every
    /// other `serve` process of the same binary at startup (`ServeReaper`, cupertino #242),
    /// to clean up orphans left by MCP-host config reloads. This app is a long-lived client
    /// that coexists with the user's other cupertino MCP servers (Claude Desktop, Codex,
    /// Cursor, ...), so it must NOT reap them, and reaping would also entangle it in the
    /// "Transport closed" fight cupertino #280 describes. `--no-reap` is cupertino's own
    /// prescription for such clients.
    /// - Parameter executable: the cupertino binary name or absolute path.
    public static func live(executable: String = "cupertino") -> any Backend.Documentation {
        guard let resolved = CupertinoExecutable.resolve(name: executable) else {
            return Backend.Unavailable(failure: .executableMissing(name: executable, installHint: "brew install cupertino"))
        }
        let transport = Transport.Subprocess(command: resolved, arguments: ["serve", "--no-reap"])
        // Match cupertino's own proven client (MockAIAgent): a named client and a generous
        // request timeout. The first call cold-starts `cupertino serve` against a multi-GB
        // read-only index, which can exceed the 30s default; cupertino's CI uses 60s for the
        // worst observed cold start (cupertino cold-start CI timeout note).
        let client = MCPClient(
            transport: transport,
            clientName: "Cupertino Desktop",
            clientVersion: "1.0.0",
            requestTimeout: .seconds(60),
        )
        return Backend.LocalSubprocess(client: client)
    }
}
