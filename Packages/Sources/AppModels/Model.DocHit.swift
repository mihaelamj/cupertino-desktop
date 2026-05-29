public extension Model {
    /// A single search hit from a doc-like source (apple-docs, hig, swift-evolution,
    /// swift-org, swift-book, apple-archive). One uniform shape across those sources;
    /// samples and packages have their own hit types because their nature differs.
    struct DocHit: Identifiable, Hashable, Sendable, Codable {
        public let id: String
        public let uri: DocURI
        public let source: Source
        public let title: String
        public let framework: String?
        public let snippet: String
        public let availability: [Availability]
        public let score: Double

        public init(
            id: String,
            uri: DocURI,
            source: Source,
            title: String,
            framework: String?,
            snippet: String,
            availability: [Availability] = [],
            score: Double,
        ) {
            self.id = id
            self.uri = uri
            self.source = source
            self.title = title
            self.framework = framework
            self.snippet = snippet
            self.availability = availability
            self.score = score
        }
    }
}
