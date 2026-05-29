public extension Model {
    /// A sample project identifier (cupertino's `owner/repo` slug). A wrapper so a
    /// project id is not confused with arbitrary text at call sites.
    struct SampleID: Hashable, Sendable, Codable {
        public let rawValue: String
        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }
}
