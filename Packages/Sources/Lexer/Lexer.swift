import Foundation

public class Lexer {
    public let code: String
    public var index: String.Index
    public var line = 1
    public var col = 1

    public init(code: String) {
        self.code = code
        index = code.startIndex
    }

    public var isEOF: Bool {
        index == code.endIndex
    }

    public var peekChar: Character? {
        isEOF ? nil : code[index]
    }

    public func advanceChar() -> Character? {
        if isEOF { return nil }
        let c = code[index]
        index = code.index(after: index)
        if c == "\n" {
            line += 1
            col = 1
        } else {
            col += 1
        }
        return c
    }

    /// Strict tokenization: the first lexical error aborts. Used by the compile and decompile paths,
    /// which must not build from broken source.
    public func tokenize() throws -> [Token] {
        let (tokens, errors) = tokenizeRecovering()
        if let first = errors.first { throw first }
        return tokens
    }

    /// Recovering tokenization (Dragon Book §3.1.4 panic mode): on an unexpected character the error is
    /// recorded and the character is deleted from the input (the simplest single-edit repair), and
    /// scanning continues, so ALL lexical errors are reported in one pass. An unterminated string records
    /// its error and yields the partial lexeme. Correct input pays no overhead: the recovery path only
    /// activates on error.
    public func tokenizeRecovering() -> (tokens: [Token], errors: [SyntaxError]) {
        var tokens: [Token] = []
        var errors: [SyntaxError] = []

        while !isEOF {
            skipWhitespaceAndComments()
            if isEOF { break }

            let startLine = line
            let startCol = col

            guard let c = peekChar else { break }

            if c == ":" {
                _ = advanceChar()
                tokens.append(Token(type: .colon, value: ":", line: startLine, column: startCol, endLine: line, endColumn: col))
            } else if c == "=" {
                _ = advanceChar()
                tokens.append(Token(type: .equals, value: "=", line: startLine, column: startCol, endLine: line, endColumn: col))
            } else if c == "{" {
                _ = advanceChar()
                tokens.append(Token(type: .lbrace, value: "{", line: startLine, column: startCol, endLine: line, endColumn: col))
            } else if c == "}" {
                _ = advanceChar()
                tokens.append(Token(type: .rbrace, value: "}", line: startLine, column: startCol, endLine: line, endColumn: col))
            } else if c == "[" {
                _ = advanceChar()
                tokens.append(Token(type: .lbracket, value: "[", line: startLine, column: startCol, endLine: line, endColumn: col))
            } else if c == "]" {
                _ = advanceChar()
                tokens.append(Token(type: .rbracket, value: "]", line: startLine, column: startCol, endLine: line, endColumn: col))
            } else if c == "," {
                _ = advanceChar()
                tokens.append(Token(type: .comma, value: ",", line: startLine, column: startCol, endLine: line, endColumn: col))
            } else if c == "\"" || c == "#" {
                // Determine if it is a raw string
                var hashCount = 0
                var tempIndex = index
                if c == "#" {
                    while tempIndex < code.endIndex, code[tempIndex] == "#" {
                        hashCount += 1
                        tempIndex = code.index(after: tempIndex)
                    }
                }

                let hasQuote = tempIndex < code.endIndex && code[tempIndex] == "\""

                if hasQuote {
                    // Consume the hashes
                    for _ in 0 ..< hashCount {
                        _ = advanceChar()
                    }
                    _ = advanceChar() // Consume the quote

                    // Check if it is multiline raw string
                    var isMultiline = false
                    if index < code.endIndex, code[index] == "\"" {
                        let nextNext = code.index(after: index)
                        if nextNext < code.endIndex, code[nextNext] == "\"" {
                            isMultiline = true
                            _ = advanceChar() // Consume quote
                            _ = advanceChar() // Consume quote
                        }
                    }

                    let (str, stringError) = readRawString(hashCount: hashCount, isMultiline: isMultiline)
                    if let stringError { errors.append(stringError) }
                    if isMultiline {
                        tokens.append(Token(type: .multilineString, value: str, line: startLine, column: startCol, endLine: line, endColumn: col))
                    } else {
                        tokens.append(Token(type: .string, value: str, line: startLine, column: startCol, endLine: line, endColumn: col))
                    }
                } else if c == "\"" {
                    _ = advanceChar() // Consume quote
                    var isMultiline = false
                    if index < code.endIndex, code[index] == "\"" {
                        let nextNext = code.index(after: index)
                        if nextNext < code.endIndex, code[nextNext] == "\"" {
                            isMultiline = true
                            _ = advanceChar() // Consume quote
                            _ = advanceChar() // Consume quote
                        }
                    }

                    let (str, stringError) = readRawString(hashCount: 0, isMultiline: isMultiline)
                    if let stringError { errors.append(stringError) }
                    if isMultiline {
                        tokens.append(Token(type: .multilineString, value: str, line: startLine, column: startCol, endLine: line, endColumn: col))
                    } else {
                        tokens.append(Token(type: .string, value: str, line: startLine, column: startCol, endLine: line, endColumn: col))
                    }
                } else {
                    errors.append(SyntaxError(line: line, column: col, kind: .unexpectedCharacter(String(c))))
                    _ = advanceChar() // panic-mode repair: delete the offending character and continue
                }
            } else if c == "-" || c.isNumber {
                // A minus is a number only when a digit follows; a bare `-` is a lexical error, not the
                // number "-" (which the parser would otherwise coerce to zero).
                if c == "-" {
                    let next = code.index(after: index)
                    if next >= code.endIndex || !code[next].isNumber {
                        errors.append(SyntaxError(line: line, column: col, kind: .unexpectedCharacter("-")))
                        _ = advanceChar()
                        continue
                    }
                }
                let num = readNumber()
                tokens.append(Token(type: .number, value: num, line: startLine, column: startCol, endLine: line, endColumn: col))
            } else if c.isLetter || c == "_" {
                let ident = readIdentifier()
                if ident == "let" {
                    tokens.append(Token(type: .letKeyword, value: ident, line: startLine, column: startCol, endLine: line, endColumn: col))
                } else if ident == "true" || ident == "false" {
                    tokens.append(Token(type: .boolean, value: ident, line: startLine, column: startCol, endLine: line, endColumn: col))
                } else {
                    tokens.append(Token(type: .identifier, value: ident, line: startLine, column: startCol, endLine: line, endColumn: col))
                }
            } else {
                errors.append(SyntaxError(line: line, column: col, kind: .unexpectedCharacter(String(c))))
                _ = advanceChar() // panic-mode repair: delete the offending character and continue
            }
        }
        return (tokens, errors)
    }

    private func skipWhitespaceAndComments() {
        while !isEOF {
            guard let c = peekChar else { return }
            if c.isWhitespace {
                _ = advanceChar()
            } else if code[index...].hasPrefix("//") {
                // Skip line comment
                while !isEOF, peekChar != "\n" {
                    _ = advanceChar()
                }
            } else if code[index...].hasPrefix("/*") {
                // Skip block comment
                _ = advanceChar() // /
                _ = advanceChar() // *
                while !isEOF, !code[index...].hasPrefix("*/") {
                    _ = advanceChar()
                }
                if !isEOF {
                    _ = advanceChar() // *
                    _ = advanceChar() // /
                }
            } else {
                break
            }
        }
    }

    private func readRawString(hashCount: Int, isMultiline: Bool) -> (String, SyntaxError?) {
        var str = ""
        let closingQuotes = isMultiline ? "\"\"\"" : "\""
        let closingHashes = String(repeating: "#", count: hashCount)
        let closingDelimiter = closingQuotes + closingHashes

        while !isEOF {
            if code[index...].hasPrefix(closingDelimiter) {
                // Consume closing delimiter
                for _ in 0 ..< closingDelimiter.count {
                    _ = advanceChar()
                }
                if isMultiline {
                    return (cleanMultilineString(str), nil)
                } else {
                    return (str, nil)
                }
            }

            guard let c = peekChar else { break }

            if hashCount == 0, c == "\\" {
                _ = advanceChar() // Consume \
                if let esc = advanceChar() {
                    switch esc {
                    case "n": str.append("\n")
                    case "t": str.append("\t")
                    case "r": str.append("\r")
                    case "\\": str.append("\\")
                    case "\"": str.append("\"")
                    default:
                        str.append("\\")
                        str.append(esc)
                    }
                } else {
                    str.append("\\")
                }
            } else if let c = advanceChar() {
                str.append(c)
            }
        }
        let partial = isMultiline ? cleanMultilineString(str) : str
        return (partial, SyntaxError(line: line, column: col, kind: .unterminatedString))
    }

    private func cleanMultilineString(_ raw: String) -> String {
        guard raw.contains("\n") else { return raw }
        var lines = raw.components(separatedBy: "\n")

        // Remove first line if it is empty (from the newline immediately following the opening """)
        if let first = lines.first, first.isEmpty {
            lines.removeFirst()
        }

        if lines.isEmpty { return "" }

        // Check if the last line is purely whitespace (which is the case when closing """ is on a new line)
        let lastLine = lines.last ?? ""
        let isLastLineWhitespace = lastLine.allSatisfy(\.isWhitespace)

        let indentPrefix = isLastLineWhitespace ? lastLine : ""
        if isLastLineWhitespace {
            lines.removeLast()
        }

        // Strip the indentation prefix from all remaining lines
        let cleanedLines = lines.map { line -> String in
            if !indentPrefix.isEmpty, line.hasPrefix(indentPrefix) {
                return String(line.dropFirst(indentPrefix.count))
            }
            return line
        }

        return cleanedLines.joined(separator: "\n")
    }

    /// A number lexeme: `-? digits ( . digits )? ( [eE] [+-]? digits )?`. Maximal munch: the fractional
    /// part and exponent are consumed only when actually present (a trailing `.` or `e` is left for the
    /// next token), so `3.` lexes as `3` followed by `.`.
    private func readNumber() -> String {
        var num = ""
        if peekChar == "-" {
            num.append(advanceChar()!)
        }
        func readDigits() {
            while let c = peekChar, c.isNumber {
                num.append(advanceChar()!)
            }
        }
        readDigits()
        if peekChar == "." {
            let next = code.index(after: index)
            if next < code.endIndex, code[next].isNumber {
                num.append(advanceChar()!) // the decimal point
                readDigits()
            }
        }
        if peekChar == "e" || peekChar == "E" {
            var lookahead = code.index(after: index)
            if lookahead < code.endIndex, code[lookahead] == "+" || code[lookahead] == "-" {
                lookahead = code.index(after: lookahead)
            }
            if lookahead < code.endIndex, code[lookahead].isNumber {
                num.append(advanceChar()!) // e / E
                if peekChar == "+" || peekChar == "-" {
                    num.append(advanceChar()!)
                }
                readDigits()
            }
        }
        return num
    }

    private func readIdentifier() -> String {
        var ident = ""
        while !isEOF {
            guard let c = peekChar else { break }
            if c.isLetter || c.isNumber || c == "_" {
                ident.append(advanceChar()!)
            } else {
                break
            }
        }
        return ident
    }
}
