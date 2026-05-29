import AppModels

public extension Backend {
    /// The documentation backend contract. Pure domain verbs returning
    /// `AppModels` value types; no MCP, JSON-RPC, or cupertino types appear here.
    /// Conformers are named by locality, never by protocol:
    /// `Backend.LocalSubprocess` (out-of-process, talks to a local `cupertino
    /// serve`) and `Backend.LocalEmbedded` (in-process, direct calls, no MCP). A
    /// remote conformer is future. How each crosses (or doesn't cross) a process
    /// boundary is its own business; this contract never reveals it.
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
