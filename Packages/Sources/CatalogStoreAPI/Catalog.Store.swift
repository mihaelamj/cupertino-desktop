public extension Catalog {
    /// Resolves the currently selected Cupertino corpus for embedded targets.
    ///
    /// Concrete stores resolve a catalog install and return only the opaque corpus
    /// handle. The backend composition root passes the handle directly to
    /// CupertinoDataEngine.
    protocol Store: Sendable {
        func currentCorpus() async throws -> CorpusHandle
    }
}
