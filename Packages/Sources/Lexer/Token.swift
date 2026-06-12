import Foundation

public struct Token {
    public let type: TokenType
    public let value: String
    /// 1-based start position of the lexeme in the source.
    public let line: Int
    public let column: Int
    /// 1-based position just PAST the lexeme's last character, recorded by the scanner at the
    /// moment the lexeme ends. Positions are part of the token; estimating the end from the cooked
    /// value goes wrong the moment an escape sequence or a raw-string delimiter changes the source
    /// length (editor ranges must be source-exact). Defaults equal the start for synthetic tokens.
    public let endLine: Int
    public let endColumn: Int

    public init(type: TokenType, value: String, line: Int, column: Int, endLine: Int? = nil, endColumn: Int? = nil) {
        self.type = type
        self.value = value
        self.line = line
        self.column = column
        self.endLine = endLine ?? line
        self.endColumn = endColumn ?? column
    }
}
