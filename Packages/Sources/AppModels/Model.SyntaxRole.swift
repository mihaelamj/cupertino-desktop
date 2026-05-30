public extension Model {
    /// The kind of a highlighted source-code token. Neutral across highlighters so the
    /// markdown renderer maps roles to colors without importing any highlighting library;
    /// the `CodeHighlighting` concrete maps a backend (Splash) onto these.
    enum SyntaxRole: String, Sendable, Hashable, CaseIterable, Codable {
        case keyword
        case type
        case call
        case property
        case string
        case number
        case comment
        case dotAccess
        case preprocessing
        case plain
    }
}
