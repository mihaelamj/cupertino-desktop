import AppModels
import BackendAPI
import MCPClientAPI

public extension Backend {
    /// `Backend.Documentation` adapter for the **local, out-of-process** path: it
    /// talks to a `cupertino serve` subprocess on the same machine. The fact that
    /// the boundary is crossed with MCP/JSON-RPC is a detail of the client it holds
    /// (`Client.MCP`), not of this adapter; nothing above the protocol sees MCP.
    /// Local-remote is the axis: a future remote adapter would talk to a hosted
    /// cupertino over the network instead.
    ///
    /// The tool calls and the string/JSON to `AppModels` mapping (docs/PROTOCOL.md
    /// section 4) land in milestone M1; this scaffold fixes the shape and wiring and
    /// fails honestly with `Failure.unsupported` until each verb is implemented.
    actor LocalSubprocess: Documentation {
        private let client: any Client.MCP

        public init(client: any Client.MCP) {
            self.client = client
        }

        // MARK: Connecting

        public func connect() async throws {
            try await client.connect()
        }

        public func disconnect() async {
            await client.disconnect()
        }

        // MARK: FrameworkBrowsing

        public func listFrameworks() async throws -> [Model.Framework] {
            throw Failure.unsupported(operation: "listFrameworks")
        }

        // MARK: DocumentReading

        public func readDocument(_: Model.DocURI) async throws -> Model.DocPage {
            throw Failure.unsupported(operation: "readDocument")
        }

        // MARK: Searching

        public func searchDocs(_: Model.DocsQuery) async throws -> [Model.DocHit] {
            throw Failure.unsupported(operation: "searchDocs")
        }

        public func searchSamples(_: Model.SampleQuery) async throws -> Model.SampleResults {
            throw Failure.unsupported(operation: "searchSamples")
        }

        public func searchPackages(_: Model.PackageQuery) async throws -> [Model.PackageHit] {
            throw Failure.unsupported(operation: "searchPackages")
        }

        public func searchEverything(_: Model.UnifiedQuery) async throws -> Model.UnifiedResults {
            throw Failure.unsupported(operation: "searchEverything")
        }

        // MARK: SampleBrowsing

        public func listSamples(framework _: String?, limit _: Int) async throws -> [Model.SampleProject] {
            throw Failure.unsupported(operation: "listSamples")
        }

        public func readSample(_: Model.SampleID) async throws -> Model.SampleProject {
            throw Failure.unsupported(operation: "readSample")
        }

        public func readSampleFile(_: Model.SampleID, path _: String) async throws -> Model.SampleFile {
            throw Failure.unsupported(operation: "readSampleFile")
        }

        // MARK: CodeIntelligence

        public func searchSymbols(_: Model.SymbolQuery) async throws -> [Model.SymbolHit] {
            throw Failure.unsupported(operation: "searchSymbols")
        }

        public func searchConformances(to _: String, framework _: String?, limit _: Int) async throws -> [Model.SymbolHit] {
            throw Failure.unsupported(operation: "searchConformances")
        }

        public func searchPropertyWrappers(_: String, framework _: String?, limit _: Int) async throws -> [Model.SymbolHit] {
            throw Failure.unsupported(operation: "searchPropertyWrappers")
        }

        public func searchConcurrency(_: Model.ConcurrencyPattern, framework _: String?, limit _: Int) async throws -> [Model.SymbolHit] {
            throw Failure.unsupported(operation: "searchConcurrency")
        }

        public func searchGenerics(constraint _: String, framework _: String?, limit _: Int) async throws -> [Model.SymbolHit] {
            throw Failure.unsupported(operation: "searchGenerics")
        }

        public func inheritance(of _: String, direction _: Model.InheritanceDirection, depth _: Int, framework _: String?) async throws -> Model.InheritanceTree {
            throw Failure.unsupported(operation: "inheritance")
        }
    }
}
