import AppModels

public extension Backend {
    /// Search. Result-faithful: each source nature returns its own type rather than
    /// being flattened into one list. `searchEverything` is the "all" scope.
    protocol Searching: Sendable {
        func searchDocs(_ query: Model.DocsQuery) async throws -> [Model.DocHit]
        func searchSamples(_ query: Model.SampleQuery) async throws -> Model.SampleResults
        func searchPackages(_ query: Model.PackageQuery) async throws -> [Model.PackageHit]
        func searchEverything(_ query: Model.UnifiedQuery) async throws -> Model.UnifiedResults
    }
}
