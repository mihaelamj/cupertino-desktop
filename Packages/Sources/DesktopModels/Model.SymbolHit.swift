public extension Model {
    /// A symbol search result (`search_symbols` and the symbol-graph tools).
    struct SymbolHit: Identifiable, Hashable, Sendable {
        public let id: String
        public let name: String
        public let kind: String
        public let uri: DocURI?

        public init(id: String, name: String, kind: String, uri: DocURI?) {
            self.id = id
            self.name = name
            self.kind = kind
            self.uri = uri
        }
    }
}
