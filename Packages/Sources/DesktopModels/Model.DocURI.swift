public extension Model {
    /// A documentation resource URI, e.g. `apple-docs://swiftui/documentation_swiftui_view`.
    /// A wrapper rather than a bare `String` so a URI cannot be confused with
    /// arbitrary text at call sites; scheme/path validation lands with M1.
    struct DocURI: Hashable, Sendable {
        public let rawValue: String

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }
}
