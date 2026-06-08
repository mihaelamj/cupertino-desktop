public extension Backend {
    /// Lifecycle shared by every backend capability. What "connect" means differs
    /// per adapter (spawn a subprocess and handshake, or initialize an embedded reader), but
    /// the contract above the seam is identical.
    protocol Connecting: Sendable {
        func connect() async throws
        func disconnect() async
    }
}
