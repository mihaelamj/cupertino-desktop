public extension Model {
    /// A symbol search result (`searchSymbols` and the symbol-graph queries:
    /// conformances, property wrappers, concurrency, generics).
    struct SymbolHit: Identifiable, Hashable, Sendable, Codable {
        public let id: String
        public let docURI: DocURI
        public let docTitle: String
        public let framework: String
        public let name: String
        public let kind: SymbolKind
        public let signature: String?
        public let attributes: [String]
        public let conformances: [String]
        public let genericParams: String?
        public let isAsync: Bool
        public let isPublic: Bool

        public init(
            id: String,
            docURI: DocURI,
            docTitle: String,
            framework: String,
            name: String,
            kind: SymbolKind,
            signature: String? = nil,
            attributes: [String] = [],
            conformances: [String] = [],
            genericParams: String? = nil,
            isAsync: Bool = false,
            isPublic: Bool = true,
        ) {
            self.id = id
            self.docURI = docURI
            self.docTitle = docTitle
            self.framework = framework
            self.name = name
            self.kind = kind
            self.signature = signature
            self.attributes = attributes
            self.conformances = conformances
            self.genericParams = genericParams
            self.isAsync = isAsync
            self.isPublic = isPublic
        }
    }
}
