public extension Model {
    /// A documentation resource URI, e.g. `apple-docs://swiftui/documentation_swiftui_view`.
    /// A validated wrapper rather than a bare `String`, so a URI cannot be confused
    /// with arbitrary text at call sites. The failable initializer rejects anything
    /// whose scheme is not a known `Model.Source` scheme or that has an empty path.
    struct DocURI: Hashable, Sendable, Codable {
        public let rawValue: String

        public init?(_ rawValue: String) {
            guard let separator = rawValue.firstRange(of: "://") else { return nil }
            let scheme = String(rawValue[..<separator.lowerBound])
            let path = rawValue[separator.upperBound...]
            guard !path.isEmpty, Model.Source.allCases.contains(where: { $0.scheme == scheme }) else {
                return nil
            }
            self.rawValue = rawValue
        }
    }
}
