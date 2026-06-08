import Foundation

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
        /// The backend executable (e.g. `cupertino`) is not installed, so it cannot be
        /// launched. Carries an actionable install hint for the UI to present.
        case executableMissing(name: String, installHint: String)
    }
}

extension Backend.Failure: LocalizedError {
    /// A user-facing message. Only the cases the UI presents verbatim override the default;
    /// the rest fall back to the system description, so existing behavior is unchanged.
    public var errorDescription: String? {
        switch self {
        case let .executableMissing(name, installHint):
            "\(name) is not installed. Install it with: \(installHint)"
        default:
            nil
        }
    }
}
