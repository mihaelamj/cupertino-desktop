public extension Backend {
    /// Errors surfaced across the backend seam, framework-agnostic so the UI can
    /// present them without knowing which conformer produced them.
    enum Failure: Error, Sendable {
        case notConnected
        case notImplemented
        case transport(String)
        case decoding(String)
        case backend(String)
    }
}
