import AppModels

public extension Backend {
    /// Browsing and reading sample-code projects and their files.
    protocol SampleBrowsing: Sendable {
        func listSamples(framework: String?, limit: Int) async throws -> [Model.SampleProject]
        func readSample(_ id: Model.SampleID) async throws -> Model.SampleProject
        func readSampleFile(_ id: Model.SampleID, path: String) async throws -> Model.SampleFile
    }
}
