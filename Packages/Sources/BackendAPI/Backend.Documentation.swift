import AppModels

public extension Backend {
    /// The documentation backend contract. Pure domain verbs returning
    /// `AppModels` value types; no MCP, JSON-RPC, or cupertino types appear
    /// here. Conformers: `Backend.MCP` (macOS, MCP over a transport) and the
    /// future `EmbeddedBackend` (iOS/mac, direct calls).
    protocol Documentation: Sendable {
        func connect() async throws
        func disconnect() async

        func listFrameworks() async throws -> [Model.Framework]
        func searchDocs(_ query: String, limit: Int) async throws -> [Model.SearchHit]
        func readDocument(uri: Model.DocURI) async throws -> Model.DocPage

        func listSamples(framework: String?, limit: Int) async throws -> [Model.SampleProject]
        func readSample(projectID: String) async throws -> Model.SampleProject
        func readSampleFile(projectID: String, path: String) async throws -> Model.SampleFile

        func searchSymbols(_ query: String, limit: Int) async throws -> [Model.SymbolHit]
        func inheritance(forSymbol id: String) async throws -> Model.DocPage
    }
}
