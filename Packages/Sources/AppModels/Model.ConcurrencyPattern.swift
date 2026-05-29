public extension Model {
    /// A Swift concurrency pattern to search for (`searchConcurrency`). Mirrors the
    /// patterns cupertino's `search_concurrency` tool accepts.
    enum ConcurrencyPattern: String, Sendable, Codable, CaseIterable {
        case async
        case actor
        case sendable
        case mainActor
        case task
        case asyncSequence
    }
}
