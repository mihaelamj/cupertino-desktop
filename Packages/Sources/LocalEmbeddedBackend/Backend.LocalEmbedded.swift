import AppModels
import BackendAPI

public extension Backend {
    /// `Backend.Documentation` adapter for the **local, in-process** path: it runs
    /// cupertino's read path inside this process, with no subprocess, no transport,
    /// and no MCP at all. This is the only way on iOS (which cannot spawn a
    /// subprocess); it is **iOS-only** (the macOS app uses the subprocess adapter on
    /// purpose, to exercise the real brew binary). It is still an **adapter**: it
    /// maps cupertino's typed read services to `AppModels` and is the only place
    /// those services are named.
    ///
    /// The cupertino service wiring (docs/PROTOCOL.md section 4) lands in milestone
    /// M7/M8; this scaffold fixes the shape and fails honestly with
    /// `Failure.unsupported` until each verb is implemented.
    actor LocalEmbedded: Documentation {
        public init() {}

        // MARK: Connecting

        public func connect() async throws {}
        public func disconnect() async {}

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
