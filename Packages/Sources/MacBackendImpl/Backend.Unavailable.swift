import AppModels
import BackendAPI

extension Backend {
    /// The backend returned when cupertino is not installed: every verb fails with the same
    /// actionable `Failure` (carrying the install hint), so the UI presents one clear
    /// "install cupertino" ContentUnavailable state instead of a generic transport error.
    /// `MacBackend.live()` returns this when the executable cannot be resolved; `connect()`
    /// is the first call the feature makes, so that is where the message surfaces.
    struct Unavailable: Documentation {
        let failure: Failure

        func connect() async throws {
            throw failure
        }

        func disconnect() async {}

        func listFrameworks() async throws -> [Model.Framework] {
            throw failure
        }

        func listSources() async throws -> [Model.Source] {
            throw failure
        }

        func listSourceHierarchy(source _: Model.Source, level _: Int, parent _: String?) async throws -> [Model.HierarchyItem] {
            throw failure
        }

        func readDocument(_: Model.DocURI) async throws -> Model.DocPage {
            throw failure
        }

        func searchDocs(_: Model.DocsQuery) async throws -> [Model.DocHit] {
            throw failure
        }

        func searchSamples(_: Model.SampleQuery) async throws -> Model.SampleResults {
            throw failure
        }

        func searchPackages(_: Model.PackageQuery) async throws -> [Model.PackageHit] {
            throw failure
        }

        func searchEverything(_: Model.UnifiedQuery) async throws -> Model.UnifiedResults {
            throw failure
        }

        func listSamples(framework _: String?, limit _: Int) async throws -> [Model.SampleProject] {
            throw failure
        }

        func readSample(_: Model.SampleID) async throws -> Model.SampleProject {
            throw failure
        }

        func readSampleFile(_: Model.SampleID, path _: String) async throws -> Model.SampleFile {
            throw failure
        }

        func searchSymbols(_: Model.SymbolQuery) async throws -> [Model.SymbolHit] {
            throw failure
        }

        func searchConformances(to _: String, framework _: String?, limit _: Int) async throws -> [Model.SymbolHit] {
            throw failure
        }

        func searchPropertyWrappers(_: String, framework _: String?, limit _: Int) async throws -> [Model.SymbolHit] {
            throw failure
        }

        func searchConcurrency(_: Model.ConcurrencyPattern, framework _: String?, limit _: Int) async throws -> [Model.SymbolHit] {
            throw failure
        }

        func searchGenerics(constraint _: String, framework _: String?, limit _: Int) async throws -> [Model.SymbolHit] {
            throw failure
        }

        func inheritance(of _: String, direction _: Model.InheritanceDirection, depth _: Int, framework _: String?) async throws -> Model.InheritanceTree {
            throw failure
        }
    }
}
