import AppModels
@preconcurrency import Splash

public extension Highlight {
    /// A `Model.CodeHighlighting` backed by Splash's Swift grammar. Splash only knows
    /// Swift, so this highlights Swift (and untagged code, which in this corpus is almost
    /// always Swift) and returns a single plain token for languages it should not guess at.
    /// The Splash highlighter is created per call so this stays a trivially `Sendable`
    /// value type behind the seam.
    struct Splash: Model.CodeHighlighting {
        public init() {}

        public func tokens(in code: String, language: String?) -> [Model.SyntaxToken] {
            guard Self.isSwift(language) else { return [Model.SyntaxToken(text: code, role: .plain)] }
            return SyntaxHighlighter(format: TokenAccumulator()).highlight(code)
        }

        private static func isSwift(_ language: String?) -> Bool {
            guard let language, !language.isEmpty else { return true }
            return language.lowercased() == "swift"
        }
    }

    /// A Splash `OutputFormat` that accumulates role-tagged `Model.SyntaxToken`s instead of
    /// producing styled text, so the mapping from Splash's `TokenType` to our neutral
    /// `Model.SyntaxRole` lives here and nothing above the seam sees Splash.
    private struct TokenAccumulator: OutputFormat {
        func makeBuilder() -> Builder {
            Builder()
        }

        struct Builder: OutputBuilder {
            private var tokens: [Model.SyntaxToken] = []

            mutating func addToken(_ token: String, ofType type: TokenType) {
                tokens.append(Model.SyntaxToken(text: token, role: Builder.role(for: type)))
            }

            mutating func addPlainText(_ text: String) {
                tokens.append(Model.SyntaxToken(text: text, role: .plain))
            }

            mutating func addWhitespace(_ whitespace: String) {
                tokens.append(Model.SyntaxToken(text: whitespace, role: .plain))
            }

            func build() -> [Model.SyntaxToken] {
                tokens
            }

            private static func role(for type: TokenType) -> Model.SyntaxRole {
                switch type {
                case .keyword: .keyword
                case .string: .string
                case .type: .type
                case .call: .call
                case .number: .number
                case .comment: .comment
                case .property: .property
                case .dotAccess: .dotAccess
                case .preprocessing: .preprocessing
                case .custom: .plain
                }
            }
        }
    }
}
