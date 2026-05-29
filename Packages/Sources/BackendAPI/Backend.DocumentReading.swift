import AppModels

public extension Backend {
    /// Reading a single documentation page by URI.
    protocol DocumentReading: Sendable {
        func readDocument(_ uri: Model.DocURI) async throws -> Model.DocPage
    }
}
