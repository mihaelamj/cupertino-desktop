import AppModels
import Foundation

public extension Presentation {
    /// A parsed representation of a CDSL (Cupertino Data State Language) script.
    /// Conforms to `PresentationValidatable` to support Matt Polzin's OpenAPIKit validation idiom.
    struct CDSLProgram: PresentationValidatable, Sendable {
        public enum Statement: Sendable, Equatable {
            case dispatch(ActionName, Value)
            case assertVM(String, Operator, Value)
            case awaitTasks
        }

        public enum Value: Equatable, Sendable {
            case string(String)
            case number(Int)
            case boolean(Bool)
            case nilValue
            case list([Value])

            public func asString() throws -> String {
                switch self {
                case let .string(str): return str
                default: throw CLILError.runtimeError("Expected String, got \(self)")
                }
            }

            public func asInt() throws -> Int {
                switch self {
                case let .number(num): return num
                default: throw CLILError.runtimeError("Expected Integer, got \(self)")
                }
            }
        }

        public enum Operator: String, Sendable, CaseIterable {
            case eq = "=="
            case ne = "!="
            case contains
        }

        public enum ActionName: String, Sendable, CaseIterable {
            case onAppeared, onRetried, selectSource, selectFramework, selectDocument, openDocument
            case search, toggleSource, changeLimit, resizeText
        }

        public let statements: [Statement]

        public init(statements: [Statement]) {
            self.statements = statements
        }

        public static func offer(_ document: CDSLProgram) -> [(subject: Any, codingPath: [CodingKey])] {
            var items: [(subject: Any, codingPath: [CodingKey])] = []
            items.append((document, []))
            for (index, stmt) in document.statements.enumerated() {
                items.append((stmt, [AnyCodingKey(intValue: index)]))
            }
            return items
        }
    }
}

// MARK: - CDSL Tokenizer & Lexer

public struct CDSLToken: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case dispatch, assert, vm, await, tasks
        case identifier(String)
        case string(String)
        case number(Int)
        case boolean(Bool)
        case op(String)
        case lparen, rparen, lbracket, rbracket, comma
        case nilLiteral
        case eof

        public var identifierString: String? {
            switch self {
            case let .identifier(str): str
            case .dispatch: "dispatch"
            case .assert: "assert"
            case .vm: "vm"
            case .await: "await"
            case .tasks: "tasks"
            case .nilLiteral: "nil"
            case let .string(str): str
            case let .number(num): String(num)
            case let .boolean(bool): String(bool)
            case let .op(opStr): opStr
            default: nil
            }
        }
    }

    public let kind: Kind
    public let line: Int
    public let column: Int
}

public extension Presentation.CDSLProgram {
    /// A panic-mode recovering scanner/lexer for CDSL.
    struct Lexer {
        public let input: String
        private var index: String.Index
        private var line = 1
        private var column = 1

        public init(input: String) {
            self.input = input
            index = input.startIndex
        }

        public mutating func tokenize() -> (tokens: [CDSLToken], errors: [Presentation.CLILError]) {
            var tokens: [CDSLToken] = []
            var errors: [Presentation.CLILError] = []

            while index < input.endIndex {
                skipWhitespaceAndComments()
                if index >= input.endIndex { break }

                let currentLine = line
                let currentColumn = column
                let char = input[index]

                if char == "(" {
                    advance()
                    tokens.append(CDSLToken(kind: .lparen, line: currentLine, column: currentColumn))
                } else if char == ")" {
                    advance()
                    tokens.append(CDSLToken(kind: .rparen, line: currentLine, column: currentColumn))
                } else if char == "[" {
                    advance()
                    tokens.append(CDSLToken(kind: .lbracket, line: currentLine, column: currentColumn))
                } else if char == "]" {
                    advance()
                    tokens.append(CDSLToken(kind: .rbracket, line: currentLine, column: currentColumn))
                } else if char == "," {
                    advance()
                    tokens.append(CDSLToken(kind: .comma, line: currentLine, column: currentColumn))
                } else if char == "=" {
                    advance()
                    if index < input.endIndex, input[index] == "=" {
                        advance()
                        tokens.append(CDSLToken(kind: .op("=="), line: currentLine, column: currentColumn))
                    } else {
                        errors.append(Presentation.CLILError.lexicalError("Unexpected '=' character at line \(currentLine), column \(currentColumn)"))
                    }
                } else if char == "!" {
                    advance()
                    if index < input.endIndex, input[index] == "=" {
                        advance()
                        tokens.append(CDSLToken(kind: .op("!="), line: currentLine, column: currentColumn))
                    } else {
                        errors.append(Presentation.CLILError.lexicalError("Unexpected '!' character at line \(currentLine), column \(currentColumn)"))
                    }
                } else if char == "\"" {
                    advance()
                    var strValue = ""
                    var terminated = false
                    while index < input.endIndex {
                        if input[index] == "\"" {
                            terminated = true
                            advance()
                            break
                        }
                        strValue.append(input[index])
                        advance()
                    }
                    if !terminated {
                        errors.append(Presentation.CLILError.lexicalError("Unterminated string literal at line \(currentLine), column \(currentColumn)"))
                    }
                    tokens.append(CDSLToken(kind: .string(strValue), line: currentLine, column: currentColumn))
                } else if char.isNumber {
                    var numStr = ""
                    while index < input.endIndex, input[index].isNumber {
                        numStr.append(input[index])
                        advance()
                    }
                    if let num = Int(numStr) {
                        tokens.append(CDSLToken(kind: .number(num), line: currentLine, column: currentColumn))
                    } else {
                        errors.append(Presentation.CLILError.lexicalError("Invalid number format '\(numStr)' at line \(currentLine), column \(currentColumn)"))
                    }
                } else if char.isLetter || char == "_" {
                    var ident = ""
                    while index < input.endIndex, input[index].isLetter || input[index].isNumber || input[index] == "_" || input[index] == "-" {
                        ident.append(input[index])
                        advance()
                    }

                    switch ident {
                    case "dispatch": tokens.append(CDSLToken(kind: .dispatch, line: currentLine, column: currentColumn))
                    case "assert": tokens.append(CDSLToken(kind: .assert, line: currentLine, column: currentColumn))
                    case "vm": tokens.append(CDSLToken(kind: .vm, line: currentLine, column: currentColumn))
                    case "await": tokens.append(CDSLToken(kind: .await, line: currentLine, column: currentColumn))
                    case "tasks": tokens.append(CDSLToken(kind: .tasks, line: currentLine, column: currentColumn))
                    case "nil": tokens.append(CDSLToken(kind: .nilLiteral, line: currentLine, column: currentColumn))
                    case "true": tokens.append(CDSLToken(kind: .boolean(true), line: currentLine, column: currentColumn))
                    case "false": tokens.append(CDSLToken(kind: .boolean(false), line: currentLine, column: currentColumn))
                    case "contains": tokens.append(CDSLToken(kind: .op("contains"), line: currentLine, column: currentColumn))
                    default:
                        tokens.append(CDSLToken(kind: .identifier(ident), line: currentLine, column: currentColumn))
                    }
                } else {
                    errors.append(Presentation.CLILError.lexicalError("Unexpected character '\(char)' at line \(currentLine), column \(currentColumn)"))
                    advance()
                }
            }

            tokens.append(CDSLToken(kind: .eof, line: line, column: column))
            return (tokens, errors)
        }

        private mutating func advance() {
            guard index < input.endIndex else { return }
            let char = input[index]
            index = input.index(after: index)
            if char == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }

        private mutating func skipWhitespaceAndComments() {
            while index < input.endIndex {
                let char = input[index]
                if char.isWhitespace {
                    advance()
                } else if char == "#" {
                    while index < input.endIndex, input[index] != "\n" {
                        advance()
                    }
                } else {
                    break
                }
            }
        }
    }
}

// MARK: - CDSL Parser

public extension Presentation.CDSLProgram {
    /// A hand-coded LL(1) recursive-descent parser for CDSL supporting panic-mode resynchronization.
    struct Parser {
        private let tokens: [CDSLToken]
        private var index = 0
        private var currentToken: CDSLToken

        public init(tokens: [CDSLToken]) {
            self.tokens = tokens
            currentToken = tokens.first ?? CDSLToken(kind: .eof, line: 1, column: 1)
        }

        public mutating func parse() -> (program: Presentation.CDSLProgram?, errors: [Presentation.CLILError]) {
            var statements: [Presentation.CDSLProgram.Statement] = []
            var errors: [Presentation.CLILError] = []

            while currentToken.kind != .eof {
                do {
                    try statements.append(parseStatement())
                } catch let err as Presentation.CLILError {
                    errors.append(err)
                    recover()
                } catch {
                    errors.append(Presentation.CLILError.syntaxError(error.localizedDescription))
                    recover()
                }
            }

            return (errors.isEmpty ? Presentation.CDSLProgram(statements: statements) : nil, errors)
        }

        private mutating func consume(_ kind: CDSLToken.Kind) throws {
            if currentToken.kind == kind {
                consumeRaw()
            } else {
                throw Presentation.CLILError.syntaxError("Expected token \(kind), got \(currentToken.kind) at line \(currentToken.line), column \(currentToken.column)")
            }
        }

        private mutating func consumeRaw() {
            if index < tokens.count - 1 {
                index += 1
                currentToken = tokens[index]
            } else {
                currentToken = CDSLToken(kind: .eof, line: currentToken.line, column: currentToken.column)
            }
        }

        private mutating func recover() {
            // Panic mode: resynchronize to start of next statement or EOF
            while currentToken.kind != .eof {
                switch currentToken.kind {
                case .dispatch, .assert, .await:
                    return
                default:
                    consumeRaw()
                }
            }
        }

        private mutating func parseStatement() throws -> Presentation.CDSLProgram.Statement {
            switch currentToken.kind {
            case .dispatch:
                try consume(.dispatch)
                guard let actionNameStr = currentToken.kind.identifierString,
                      let action = Presentation.CDSLProgram.ActionName(rawValue: actionNameStr)
                else {
                    throw Presentation.CLILError.syntaxError("Expected action name, got \(currentToken.kind) at line \(currentToken.line)")
                }
                try consume(currentToken.kind)

                try consume(.lparen)
                let value = try parseValue()
                try consume(.rparen)

                return .dispatch(action, value)

            case .assert:
                try consume(.assert)
                try consume(.vm)

                guard let property = currentToken.kind.identifierString else {
                    throw Presentation.CLILError.syntaxError("Expected property identifier, got \(currentToken.kind) at line \(currentToken.line)")
                }
                try consume(currentToken.kind)

                guard case let .op(opStr) = currentToken.kind,
                      let op = Presentation.CDSLProgram.Operator(rawValue: opStr)
                else {
                    throw Presentation.CLILError.syntaxError("Expected Operator, got \(currentToken.kind) at line \(currentToken.line)")
                }
                try consume(currentToken.kind)

                let expected = try parseValue()
                return .assertVM(property, op, expected)

            case .await:
                try consume(.await)
                try consume(.tasks)
                return .awaitTasks

            default:
                throw Presentation.CLILError.syntaxError("Unexpected token \(currentToken.kind) starting statement at line \(currentToken.line)")
            }
        }

        private mutating func parseValue() throws -> Presentation.CDSLProgram.Value {
            switch currentToken.kind {
            case let .string(str):
                try consume(currentToken.kind)
                return .string(str)
            case let .number(num):
                try consume(currentToken.kind)
                return .number(num)
            case let .boolean(bool):
                try consume(currentToken.kind)
                return .boolean(bool)
            case .nilLiteral:
                try consume(.nilLiteral)
                return .nilValue
            case .lbracket:
                try consume(.lbracket)
                var elements: [Presentation.CDSLProgram.Value] = []
                if currentToken.kind != .rbracket {
                    try elements.append(parseValue())
                    while currentToken.kind == .comma {
                        try consume(.comma)
                        try elements.append(parseValue())
                    }
                }
                try consume(.rbracket)
                return .list(elements)
            default:
                if let ident = currentToken.kind.identifierString {
                    try consume(currentToken.kind)
                    return .string(ident)
                }
                throw Presentation.CLILError.syntaxError("Expected value literal, got \(currentToken.kind) at line \(currentToken.line)")
            }
        }
    }
}
