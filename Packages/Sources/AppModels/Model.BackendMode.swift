public extension Model {
    /// How the macOS app reaches the documentation backend.
    ///
    /// `mcpSubprocess` spawns a local `cupertino serve` and speaks MCP over stdio. It is the
    /// default and the only mode that works for direct (Developer ID, notarized) distribution,
    /// where the app may spawn the Homebrew-installed binary. `embedded` reads the corpus
    /// in-process with no subprocess: the App Sandbox / Mac App Store safe path, the same
    /// adapter iOS uses. Persisted in `Model.AppSettings`.
    enum BackendMode: String, Codable, Sendable, CaseIterable {
        case mcpSubprocess
        case embedded
    }
}

public extension Model.BackendMode {
    /// SF Symbol for the connection-type indicator. `terminal` for the local
    /// `cupertino serve` subprocess (a CLI process the app drives over stdio);
    /// `internaldrive` for the in-process embedded corpus (local, built-in data).
    var systemImage: String {
        switch self {
        case .mcpSubprocess: "terminal"
        case .embedded: "internaldrive"
        }
    }

    /// Short human label for the connection type (menu title, tooltip, accessibility).
    var label: String {
        switch self {
        case .mcpSubprocess: "Local MCP (cupertino serve)"
        case .embedded: "Embedded corpus"
        }
    }
}
