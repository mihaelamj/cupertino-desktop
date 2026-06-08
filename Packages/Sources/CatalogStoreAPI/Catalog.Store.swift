public extension Catalog {
    /// Resolves the currently selected Cupertino corpus for embedded targets.
    ///
    /// Concrete stores may return a bundled corpus or a downloaded corpus. The backend
    /// composition root passes the handle directly to CupertinoDataEngine.
    protocol Store: Sendable {
        func currentCorpus() async throws -> CorpusHandle
    }
}
