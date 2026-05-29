public extension Model {
    /// A minimum-version floor applied to a search, filtering out results that
    /// require a newer OS than specified. Mirrors cupertino's `min_*` filters.
    struct PlatformFloor: Hashable, Sendable, Codable {
        public var iOS: String?
        public var macOS: String?
        public var tvOS: String?
        public var watchOS: String?
        public var visionOS: String?
        public var swift: String?

        public init(
            iOS: String? = nil,
            macOS: String? = nil,
            tvOS: String? = nil,
            watchOS: String? = nil,
            visionOS: String? = nil,
            swift: String? = nil,
        ) {
            self.iOS = iOS
            self.macOS = macOS
            self.tvOS = tvOS
            self.watchOS = watchOS
            self.visionOS = visionOS
            self.swift = swift
        }

        public static let none = PlatformFloor()
    }
}
