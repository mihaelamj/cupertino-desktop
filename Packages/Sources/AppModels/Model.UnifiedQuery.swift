public extension Model {
    /// The "everything" scope (`searchEverything`): one text applied across all
    /// source natures, with a per-source limit.
    struct UnifiedQuery: Hashable, Sendable {
        public var text: String
        public var framework: String?
        public var floor: PlatformFloor
        public var limitPerSource: Int

        public init(
            text: String,
            framework: String? = nil,
            floor: PlatformFloor = .none,
            limitPerSource: Int = 10,
        ) {
            self.text = text
            self.framework = framework
            self.floor = floor
            self.limitPerSource = limitPerSource
        }
    }
}
