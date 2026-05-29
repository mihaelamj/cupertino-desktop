import AppModels
import BackendAPI
import MCPClientAPI

public extension Backend {
    /// `Backend.Documentation` conformer that talks to cupertino over MCP
    /// (JSON-RPC) via an injected `MCPClient`. The MCP wire protocol is confined
    /// to this conformer and the packages it uses; nothing above
    /// `Backend.Documentation` sees it. This is the macOS path (the client's
    /// transport spawns `cupertino serve`); a remote transport would reuse this
    /// same conformer unchanged.
    ///
    /// The string/JSON to model mapping per tool (docs/DESIGN.md section 6)
    /// lands in milestone M1; this scaffold fixes the shape and the wiring.
    actor MCP: Documentation {
        private let client: any Client.MCP

        public init(client: any Client.MCP) {
            self.client = client
        }

        public func connect() async throws {
            try await client.connect()
        }

        public func disconnect() async {
            await client.disconnect()
        }

        public func listFrameworks() async throws -> [Model.Framework] {
            throw Failure.notImplemented
        }

        public func searchDocs(_: String, limit _: Int) async throws -> [Model.SearchHit] {
            throw Failure.notImplemented
        }

        public func readDocument(uri _: Model.DocURI) async throws -> Model.DocPage {
            throw Failure.notImplemented
        }

        public func listSamples(framework _: String?, limit _: Int) async throws -> [Model.SampleProject] {
            throw Failure.notImplemented
        }

        public func readSample(projectID _: String) async throws -> Model.SampleProject {
            throw Failure.notImplemented
        }

        public func readSampleFile(projectID _: String, path _: String) async throws -> Model.SampleFile {
            throw Failure.notImplemented
        }

        public func searchSymbols(_: String, limit _: Int) async throws -> [Model.SymbolHit] {
            throw Failure.notImplemented
        }

        public func inheritance(forSymbol _: String) async throws -> Model.DocPage {
            throw Failure.notImplemented
        }
    }
}
