public extension Model {
    /// A Swift package search hit (`searchPackages`). Packages carry owner/repo/path
    /// and a matched chunk, so they are their own type rather than a `DocHit`.
    struct PackageHit: Identifiable, Hashable, Sendable, Codable {
        public let id: String
        public let owner: String
        public let repo: String
        public let path: String
        public let module: String?
        public let title: String
        public let snippet: String
        public let score: Double

        public init(
            id: String,
            owner: String,
            repo: String,
            path: String,
            module: String?,
            title: String,
            snippet: String,
            score: Double,
        ) {
            self.id = id
            self.owner = owner
            self.repo = repo
            self.path = path
            self.module = module
            self.title = title
            self.snippet = snippet
            self.score = score
        }
    }
}
