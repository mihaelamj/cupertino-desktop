import AppModels

public extension Backend {
    /// Listing the documentation frameworks (the sidebar's source).
    protocol FrameworkBrowsing: Sendable {
        func listFrameworks() async throws -> [Model.Framework]
    }
}
