public extension Model {
    /// A Swift package search (`searchPackages`).
    struct PackageQuery: Hashable, Sendable {
        public var text: String
        public var appleImport: String?
        public var floor: PlatformFloor
        public var limit: Int

        public init(
            text: String,
            appleImport: String? = nil,
            floor: PlatformFloor = .none,
            limit: Int = 20,
        ) {
            self.text = text
            self.appleImport = appleImport
            self.floor = floor
            self.limit = limit
        }
    }
}
