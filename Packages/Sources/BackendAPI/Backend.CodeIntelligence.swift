import AppModels

public extension Backend {
    /// Symbol-graph queries over the corpus: symbol search, conformances, property
    /// wrappers, concurrency patterns, generic constraints, and inheritance walks.
    protocol CodeIntelligence: Sendable {
        func searchSymbols(_ query: Model.SymbolQuery) async throws -> [Model.SymbolHit]
        func searchConformances(to protocolName: String, framework: String?, limit: Int) async throws -> [Model.SymbolHit]
        func searchPropertyWrappers(_ wrapper: String, framework: String?, limit: Int) async throws -> [Model.SymbolHit]
        func searchConcurrency(_ pattern: Model.ConcurrencyPattern, framework: String?, limit: Int) async throws -> [Model.SymbolHit]
        func searchGenerics(constraint: String, framework: String?, limit: Int) async throws -> [Model.SymbolHit]
        func inheritance(of symbol: String, direction: Model.InheritanceDirection, depth: Int, framework: String?) async throws -> Model.InheritanceTree
    }
}
