import BackendAPI
import EmbeddedBackend

/// Composition root for the Mobile (iOS) backend. Mirrors `MacBackend` but wires
/// the in-process embedded conformer instead of MCP-over-subprocess. App targets
/// depend on this and get back an opaque `any Backend.Documentation`, so nothing
/// in the app or features knows which platform path is in play.
public enum MobileBackend {
    /// Build the live iOS backend: cupertino reached in-process, no subprocess.
    public static func live() -> any Backend.Documentation {
        Backend.Embedded()
    }
}
