public extension Model {
    /// A run of source code tagged with a syntax role. A highlighter turns code into a
    /// sequence of these; the renderer styles each run with the color for its role.
    struct SyntaxToken: Sendable, Hashable, Codable {
        public let text: String
        public let role: SyntaxRole

        public init(text: String, role: SyntaxRole) {
            self.text = text
            self.role = role
        }
    }
}
