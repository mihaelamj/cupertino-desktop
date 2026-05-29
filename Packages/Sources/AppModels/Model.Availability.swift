public extension Model {
    /// A single platform's availability for a hit or page. Mapped from cupertino's
    /// availability records inside the adapters.
    struct Availability: Hashable, Sendable, Codable {
        public let platform: Platform
        public let introducedAt: String?
        public let deprecated: Bool
        public let beta: Bool
        public let unavailable: Bool

        public init(
            platform: Platform,
            introducedAt: String? = nil,
            deprecated: Bool = false,
            beta: Bool = false,
            unavailable: Bool = false,
        ) {
            self.platform = platform
            self.introducedAt = introducedAt
            self.deprecated = deprecated
            self.beta = beta
            self.unavailable = unavailable
        }

        public enum Platform: String, Sendable, Codable, CaseIterable {
            case iOS
            case macOS
            case tvOS
            case watchOS
            case visionOS
        }
    }
}
