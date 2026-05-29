public extension Model {
    /// A sample-code search (`searchSamples`).
    struct SampleQuery: Hashable, Sendable {
        public var text: String
        public var framework: String?
        public var floor: PlatformFloor
        public var includeFiles: Bool
        public var limit: Int

        public init(
            text: String,
            framework: String? = nil,
            floor: PlatformFloor = .none,
            includeFiles: Bool = true,
            limit: Int = 20,
        ) {
            self.text = text
            self.framework = framework
            self.floor = floor
            self.includeFiles = includeFiles
            self.limit = limit
        }
    }
}
