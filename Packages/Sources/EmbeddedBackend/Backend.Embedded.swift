import AppModels
import BackendAPI

public extension Backend {
    /// `Backend.Documentation` conformer for the Mobile (iOS) path. iOS cannot
    /// spawn a `cupertino serve` subprocess, so instead of MCP-over-transport this
    /// conformer reaches cupertino's search/services in-process. It shares the
    /// universal `Backend.Documentation` seam with `Backend.MCP`, so features and
    /// UI cannot tell the two apart.
    ///
    /// The direct cupertino wiring (linking its search/services products and
    /// mapping their results to `Model` types) lands in a later milestone; this
    /// scaffold fixes the shape and fails honestly.
    actor Embedded: Documentation {
        public init() {}

        public func connect() async throws {}
        public func disconnect() async {}

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
