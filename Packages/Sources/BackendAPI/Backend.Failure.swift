public extension Backend {
    /// Errors surfaced across the backend seam, framework-agnostic so the UI can
    /// present them without knowing which adapter produced them. See docs/PROTOCOL.md.
    enum Failure: Error, Sendable {
        case notConnected
        case notFound(id: String)
        case unsupported(operation: String)
        case transport(String)
        case corpusUnavailable(String)
        case decoding(String)
        case backend(String)
    }
}
