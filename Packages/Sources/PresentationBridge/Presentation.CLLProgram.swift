import AppModels
import Foundation

public extension Presentation {
    /// A parsed representation of a CLL (Cupertino Layout Language) script.
    /// Conforms to `PresentationValidatable` to support Matt Polzin's OpenAPIKit validation idiom.
    struct CLLProgram: PresentationValidatable, Sendable {
        public enum Statement: Sendable, Equatable {
            case device(DeviceName, Orientation, SizeClass)
            case assertUI(String, Operator, Value)
        }

        public enum Value: Equatable, Sendable {
            case string(String)
            case number(Int)
            case boolean(Bool)
            case nilValue

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

        public enum DeviceName: String, Codable, CaseIterable, Sendable {
            case iPhone, iPad, Mac
        }

        public enum Orientation: String, Codable, CaseIterable, Sendable {
            case portrait, landscape
        }

        public enum SizeClass: String, Codable, CaseIterable, Sendable {
            case compact, regular
        }

        public enum Operator: String, Sendable, CaseIterable {
            case eq = "=="
            case ne = "!="
            case shows
            case hides
        }

        public let statements: [Statement]

        public init(statements: [Statement]) {
            self.statements = statements
        }

        public static func offer(_ document: CLLProgram) -> [(subject: Any, codingPath: [CodingKey])] {
            var items: [(subject: Any, codingPath: [CodingKey])] = []
            items.append((document, []))
            for (index, stmt) in document.statements.enumerated() {
                items.append((stmt, [AnyCodingKey(intValue: index)]))
            }
            return items
        }
    }
}

// MARK: - CLL Tokenizer & Lexer

public struct CLLToken: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case device, `in`, with, assert, ui
        case identifier(String)
        case string(String)
        case number(Int)
        case boolean(Bool)
        case op(String)
        case nilLiteral
        case eof

        public var identifierString: String? {
            switch self {
            case let .identifier(str): str
            case .device: "device"
            case .in: "in"
            case .with: "with"
            case .assert: "assert"
            case .ui: "ui"
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

public extension Presentation.CLLProgram {
    /// A panic-mode recovering scanner/lexer for CLL.
    struct Lexer {
        public let input: String
        private var index: String.Index
        private var line = 1
        private var column = 1

        public init(input: String) {
            self.input = input
            index = input.startIndex
        }

        public mutating func tokenize() -> (tokens: [CLLToken], errors: [Presentation.CLILError]) {
            var tokens: [CLLToken] = []
            var errors: [Presentation.CLILError] = []

            while index < input.endIndex {
                skipWhitespaceAndComments()
                if index >= input.endIndex { break }

                let currentLine = line
                let currentColumn = column
                let char = input[index]

                if char == "=" {
                    advance()
                    if index < input.endIndex, input[index] == "=" {
                        advance()
                        tokens.append(CLLToken(kind: .op("=="), line: currentLine, column: currentColumn))
                    } else {
                        errors.append(Presentation.CLILError.lexicalError("Unexpected '=' character at line \(currentLine), column \(currentColumn)"))
                    }
                } else if char == "!" {
                    advance()
                    if index < input.endIndex, input[index] == "=" {
                        advance()
                        tokens.append(CLLToken(kind: .op("!="), line: currentLine, column: currentColumn))
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
                    tokens.append(CLLToken(kind: .string(strValue), line: currentLine, column: currentColumn))
                } else if char.isNumber {
                    var numStr = ""
                    while index < input.endIndex, input[index].isNumber {
                        numStr.append(input[index])
                        advance()
                    }
                    if let num = Int(numStr) {
                        tokens.append(CLLToken(kind: .number(num), line: currentLine, column: currentColumn))
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
                    case "device": tokens.append(CLLToken(kind: .device, line: currentLine, column: currentColumn))
                    case "in": tokens.append(CLLToken(kind: .in, line: currentLine, column: currentColumn))
                    case "with": tokens.append(CLLToken(kind: .with, line: currentLine, column: currentColumn))
                    case "assert": tokens.append(CLLToken(kind: .assert, line: currentLine, column: currentColumn))
                    case "ui": tokens.append(CLLToken(kind: .ui, line: currentLine, column: currentColumn))
                    case "nil": tokens.append(CLLToken(kind: .nilLiteral, line: currentLine, column: currentColumn))
                    case "true": tokens.append(CLLToken(kind: .boolean(true), line: currentLine, column: currentColumn))
                    case "false": tokens.append(CLLToken(kind: .boolean(false), line: currentLine, column: currentColumn))
                    case "shows", "hides": tokens.append(CLLToken(kind: .op(ident), line: currentLine, column: currentColumn))
                    default:
                        tokens.append(CLLToken(kind: .identifier(ident), line: currentLine, column: currentColumn))
                    }
                } else {
                    errors.append(Presentation.CLILError.lexicalError("Unexpected character '\(char)' at line \(currentLine), column \(currentColumn)"))
                    advance()
                }
            }

            tokens.append(CLLToken(kind: .eof, line: line, column: column))
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

// MARK: - CLL Parser

public extension Presentation.CLLProgram {
    /// A hand-coded LL(1) recursive-descent parser for CLL supporting panic-mode resynchronization.
    struct Parser {
        private let tokens: [CLLToken]
        private var index = 0
        private var currentToken: CLLToken

        public init(tokens: [CLLToken]) {
            self.tokens = tokens
            currentToken = tokens.first ?? CLLToken(kind: .eof, line: 1, column: 1)
        }

        public mutating func parse() -> (program: Presentation.CLLProgram?, errors: [Presentation.CLILError]) {
            var statements: [Presentation.CLLProgram.Statement] = []
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

            return (errors.isEmpty ? Presentation.CLLProgram(statements: statements) : nil, errors)
        }

        private mutating func consume(_ kind: CLLToken.Kind) throws {
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
                currentToken = CLLToken(kind: .eof, line: currentToken.line, column: currentToken.column)
            }
        }

        private mutating func recover() {
            // Panic mode: resynchronize to start of next statement or EOF
            while currentToken.kind != .eof {
                switch currentToken.kind {
                case .device, .assert:
                    return
                default:
                    consumeRaw()
                }
            }
        }

        private mutating func parseStatement() throws -> Presentation.CLLProgram.Statement {
            switch currentToken.kind {
            case .device:
                try consume(.device)
                guard let deviceNameStr = currentToken.kind.identifierString,
                      let deviceName = Presentation.CLLProgram.DeviceName(rawValue: deviceNameStr)
                else {
                    throw Presentation.CLILError.syntaxError("Expected device name, got \(currentToken.kind) at line \(currentToken.line)")
                }
                try consume(currentToken.kind)

                try consume(.in)
                guard let orientationStr = currentToken.kind.identifierString,
                      let orientation = Presentation.CLLProgram.Orientation(rawValue: orientationStr)
                else {
                    throw Presentation.CLILError.syntaxError("Expected Orientation, got \(currentToken.kind) at line \(currentToken.line)")
                }
                try consume(currentToken.kind)

                try consume(.with)
                guard let sizeClassStr = currentToken.kind.identifierString,
                      let sizeClass = Presentation.CLLProgram.SizeClass(rawValue: sizeClassStr)
                else {
                    throw Presentation.CLILError.syntaxError("Expected SizeClass, got \(currentToken.kind) at line \(currentToken.line)")
                }
                try consume(currentToken.kind)

                return .device(deviceName, orientation, sizeClass)

            case .assert:
                try consume(.assert)
                try consume(.ui)

                guard let property = currentToken.kind.identifierString else {
                    throw Presentation.CLILError.syntaxError("Expected property identifier, got \(currentToken.kind) at line \(currentToken.line)")
                }
                try consume(currentToken.kind)

                guard case let .op(opStr) = currentToken.kind,
                      let op = Presentation.CLLProgram.Operator(rawValue: opStr)
                else {
                    throw Presentation.CLILError.syntaxError("Expected Operator, got \(currentToken.kind) at line \(currentToken.line)")
                }
                try consume(currentToken.kind)

                let expected = try parseValue()
                return .assertUI(property, op, expected)

            default:
                throw Presentation.CLILError.syntaxError("Unexpected token \(currentToken.kind) starting statement at line \(currentToken.line)")
            }
        }

        private mutating func parseValue() throws -> Presentation.CLLProgram.Value {
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
