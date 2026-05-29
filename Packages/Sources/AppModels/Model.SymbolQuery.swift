public extension Model {
    /// A symbol search (`searchSymbols`): any of name text, kind, and async-ness,
    /// optionally narrowed by framework and platform floor.
    struct SymbolQuery: Hashable, Sendable {
        public var text: String?
        public var kind: SymbolKind?
        public var isAsync: Bool?
        public var framework: String?
        public var floor: PlatformFloor
        public var limit: Int

        public init(
            text: String? = nil,
            kind: SymbolKind? = nil,
            isAsync: Bool? = nil,
            framework: String? = nil,
            floor: PlatformFloor = .none,
            limit: Int = 20,
        ) {
            self.text = text
            self.kind = kind
            self.isAsync = isAsync
            self.framework = framework
            self.floor = floor
            self.limit = limit
        }
    }
}
