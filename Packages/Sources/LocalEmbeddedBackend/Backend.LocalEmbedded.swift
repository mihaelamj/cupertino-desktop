import AppModels
import BackendAPI

public extension Backend {
    /// `Backend.Documentation` conformer for the **local, in-process** path: it
    /// runs cupertino's read path inside this process and calls it directly, with
    /// no subprocess, no transport, and no MCP at all. This is the only way on iOS
    /// (which cannot spawn a subprocess) and the higher-fidelity path on macOS,
    /// because it skips the markdown round-trip and reads typed results. It shares
    /// the universal `Backend.Documentation` seam with `Backend.LocalSubprocess`,
    /// so features and UI cannot tell the two apart.
    ///
    /// The direct cupertino wiring (linking its search/services products and
    /// mapping their results to `Model` types) lands in a later milestone; this
    /// scaffold fixes the shape and fails honestly.
    actor LocalEmbedded: Documentation {
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
