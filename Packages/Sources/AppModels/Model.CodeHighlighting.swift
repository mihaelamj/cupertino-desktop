public extension Model {
    /// Turns source code into role-tagged tokens. The markdown renderer depends on this
    /// seam, not on a concrete highlighter, so the highlighting library (Splash) stays
    /// behind the `CodeHighlighting` concrete and the renderer keeps a single external
    /// dependency. A nil highlighter means code renders as plain monospaced text.
    protocol CodeHighlighting: Sendable {
        /// Tokenize `code` for display. `language` is the fenced-code info string (e.g.
        /// `swift`), or nil; a highlighter may ignore languages it does not support and
        /// return a single `.plain` token.
        func tokens(in code: String, language: String?) -> [SyntaxToken]
    }
}
