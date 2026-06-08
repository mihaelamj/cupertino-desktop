import AppModels
import BackendAPI
import CatalogStoreAPI

extension MobileBackend {
    /// Backend wrapper that defers async catalog opening until the first backend call.
    actor DeferredCatalogBackend: Backend.Documentation {
        private let catalogStore: any Catalog.Store
        private var resolvedBackend: (any Backend.Documentation)?

        init(catalogStore: any Catalog.Store) {
            self.catalogStore = catalogStore
        }

        private func backend() async throws -> any Backend.Documentation {
            if let resolvedBackend {
                return resolvedBackend
            }
            let backend = try await MobileBackend.live(catalogStore: catalogStore)
            resolvedBackend = backend
            return backend
        }

        func connect() async throws {
            try await backend().connect()
        }

        func disconnect() async {
            guard let resolvedBackend else { return }
            await resolvedBackend.disconnect()
            self.resolvedBackend = nil
        }

        func listFrameworks() async throws -> [Model.Framework] {
            try await backend().listFrameworks()
        }

        func readDocument(_ uri: Model.DocURI) async throws -> Model.DocPage {
            try await backend().readDocument(uri)
        }

        func searchDocs(_ query: Model.DocsQuery) async throws -> [Model.DocHit] {
            try await backend().searchDocs(query)
        }

        func searchSamples(_ query: Model.SampleQuery) async throws -> Model.SampleResults {
            try await backend().searchSamples(query)
        }

        func searchPackages(_ query: Model.PackageQuery) async throws -> [Model.PackageHit] {
            try await backend().searchPackages(query)
        }

        func searchEverything(_ query: Model.UnifiedQuery) async throws -> Model.UnifiedResults {
            try await backend().searchEverything(query)
        }

        func listSamples(framework: String?, limit: Int) async throws -> [Model.SampleProject] {
            try await backend().listSamples(framework: framework, limit: limit)
        }

        func readSample(_ id: Model.SampleID) async throws -> Model.SampleProject {
            try await backend().readSample(id)
        }

        func readSampleFile(_ id: Model.SampleID, path: String) async throws -> Model.SampleFile {
            try await backend().readSampleFile(id, path: path)
        }

        func searchSymbols(_ query: Model.SymbolQuery) async throws -> [Model.SymbolHit] {
            try await backend().searchSymbols(query)
        }

        func searchConformances(to protocolName: String, framework: String?, limit: Int) async throws -> [Model.SymbolHit] {
            try await backend().searchConformances(to: protocolName, framework: framework, limit: limit)
        }

        func searchPropertyWrappers(_ wrapper: String, framework: String?, limit: Int) async throws -> [Model.SymbolHit] {
            try await backend().searchPropertyWrappers(wrapper, framework: framework, limit: limit)
        }

        func searchConcurrency(_ pattern: Model.ConcurrencyPattern, framework: String?, limit: Int) async throws -> [Model.SymbolHit] {
            try await backend().searchConcurrency(pattern, framework: framework, limit: limit)
        }

        func searchGenerics(constraint: String, framework: String?, limit: Int) async throws -> [Model.SymbolHit] {
            try await backend().searchGenerics(constraint: constraint, framework: framework, limit: limit)
        }

        func inheritance(
            of symbol: String,
            direction: Model.InheritanceDirection,
            depth: Int,
            framework: String?,
        ) async throws -> Model.InheritanceTree {
            try await backend().inheritance(of: symbol, direction: direction, depth: depth, framework: framework)
        }
    }
}
