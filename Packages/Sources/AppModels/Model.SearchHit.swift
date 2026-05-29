public extension Model {
    /// A single search result row (`search` / `search_docs`).
    struct SearchHit: Identifiable, Hashable, Sendable {
        public let id: String
        public let title: String
        public let uri: DocURI
        public let snippet: String
        public let framework: String?

        public init(id: String, title: String, uri: DocURI, snippet: String, framework: String?) {
            self.id = id
            self.title = title
            self.uri = uri
            self.snippet = snippet
            self.framework = framework
        }
    }
}
