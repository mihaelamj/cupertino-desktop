import AppModels
import BackendAPI
import MCPClientAPI

public extension Backend {
    /// `Backend.Documentation` conformer for the **local, out-of-process** path:
    /// it talks to a `cupertino serve` subprocess on the same machine. The fact
    /// that the boundary is crossed with MCP/JSON-RPC is a detail of the client it
    /// holds (`Client.MCP`), not of this conformer; nothing above
    /// `Backend.Documentation` sees MCP. Local-remote is the axis: a future remote
    /// conformer would talk to a hosted cupertino over the network instead.
    ///
    /// The string/JSON to model mapping per tool (docs/DESIGN.md section 6)
    /// lands in milestone M1; this scaffold fixes the shape and the wiring.
    actor LocalSubprocess: Documentation {
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
