public extension Model {
    /// A documentation search (`searchDocs`). One uniform query across the doc-like
    /// sources, narrowed by the `sources` set; the adapter routes it to the right
    /// cupertino tool/service.
    struct DocsQuery: Hashable, Sendable {
        public var text: String
        public var sources: Set<Source>
        public var framework: String?
        public var language: String?
        public var floor: PlatformFloor
        public var limit: Int

        public init(
            text: String,
            sources: Set<Source> = [.appleDocs],
            framework: String? = nil,
            language: String? = nil,
            floor: PlatformFloor = .none,
            limit: Int = 20,
        ) {
            self.text = text
            self.sources = sources
            self.framework = framework
            self.language = language
            self.floor = floor
            self.limit = limit
        }
    }
}
