import AppModels
import Foundation
import Observation

public extension Presentation {
    /// Errors thrown during CLIL compilation or simulation runs.
    enum CLILError: Error, CustomStringConvertible, Sendable {
        case lexicalError(String)
        case syntaxError(String)
        case runtimeError(String)
        case assertionFailed(String)

        public var description: String {
            switch self {
            case let .lexicalError(msg): "Lexical Error: \(msg)"
            case let .syntaxError(msg): "Syntax Error: \(msg)"
            case let .runtimeError(msg): "Runtime Error: \(msg)"
            case let .assertionFailed(msg): "Assertion Failed: \(msg)"
            }
        }
    }

    /// A parsed representation of a CLIL test script. Conforms to Matt Polzin's
    /// `PresentationValidatable` protocol so its nodes can be offered to a validator.
    struct CLILProgram: PresentationValidatable, Sendable {
        public enum Statement: Sendable, Equatable {
            case device(DeviceName, Orientation, SizeClass)
            case dispatch(ActionName, Value)
            case assert(AssertTarget, String, Operator, Value)
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

        public enum DeviceName: String, Codable, CaseIterable, Sendable {
            case iPhone, iPad, Mac
        }

        public enum Orientation: String, Codable, CaseIterable, Sendable {
            case portrait, landscape
        }

        public enum SizeClass: String, Codable, CaseIterable, Sendable {
            case compact, regular
        }

        public enum AssertTarget: Sendable {
            case vm, ui
        }

        public enum Operator: String, Sendable {
            case eq = "=="
            case ne = "!="
            case contains
            case hides
            case shows
        }

        public enum ActionName: String, Sendable {
            case onAppeared, onRetried, selectSource, selectFramework, selectDocument, openDocument
            case search, toggleSource, changeLimit, resizeText
        }

        public let statements: [Statement]

        public init(statements: [Statement]) {
            self.statements = statements
        }

        /// Offers the program itself and each parsed statement with its index path to the validator.
        public static func offer(_ document: CLILProgram) -> [(subject: Any, codingPath: [CodingKey])] {
            var items: [(subject: Any, codingPath: [CodingKey])] = []
            items.append((document, []))
            for (index, stmt) in document.statements.enumerated() {
                items.append((stmt, [AnyCodingKey(intValue: index)]))
            }
            return items
        }
    }

    /// The dual-layer CLIL interpreter that compiles and executes script statements
    /// programmatically to verify both view model state changes and visual shell layout changes.
    @MainActor
    final class CLILSimulator: Sendable {
        public enum ActiveView: String, Codable, CaseIterable, Sendable {
            case databases = "Databases"
            case frameworks = "Frameworks"
            case documents = "Documents"
            case reader = "Reader"
            case splitView = "SplitView"
        }

        public enum AssertProperty: Equatable, Sendable {
            case vm(CDSLProgram.VMProperty)
            case ui(CLLProgram.UIProperty)
        }

        public typealias DeviceName = CLILProgram.DeviceName
        public typealias Orientation = CLILProgram.Orientation
        public typealias SizeClass = CLILProgram.SizeClass

        /// Mimic representation of the visual UI layout computed according to HIG guidelines.
        public struct UIState: Equatable, Sendable {
            public var device: DeviceName = .Mac
            public var orientation: Orientation = .landscape
            public var sizeClass: SizeClass = .regular

            public var showsSidebarList: Bool {
                switch (device, sizeClass) {
                case (.iPhone, _): true
                case (.iPad, .compact): true
                case (.iPad, .regular): true
                case (.Mac, _): true
                }
            }

            public var showsDetailPane: Bool {
                switch (device, sizeClass, orientation) {
                case (.iPhone, _, _): false
                case (.iPad, .compact, _): false
                case (.iPad, .regular, _): true
                case (.Mac, _, _): true
                }
            }

            public var navigationStackDepth: Int = 0
            public var activeView: ActiveView = .databases
        }

        public private(set) var ui = UIState()

        public var onStepExecuted: (@MainActor @Sendable () async -> Void)?

        private let frameworksVM: (any FrameworkBrowserViewModelProtocol)?
        private let searchVM: (any SearchViewModelProtocol)?

        public init(
            frameworks: (any FrameworkBrowserViewModelProtocol)? = nil,
            search: (any SearchViewModelProtocol)? = nil,
        ) {
            frameworksVM = frameworks
            searchVM = search
            updateUIState()
        }

        /// Compile, validate, and run the CLIL script content.
        public func run(_ script: String) async throws {
            let lexer = Lexer(input: script)
            var parser = Parser(lexer: lexer)
            let program = try parser.parse()

            // OpenAPIKit Validation Idiom: parse first, validate second
            try CLILValidations.clilDefault.validate(program)

            for stmt in program.statements {
                try await execute(stmt)
                if let onStepExecuted {
                    await onStepExecuted()
                }
            }
        }

        /// Compile, validate, and run the CDSL script content.
        public func runCDSL(_ script: String) async throws {
            var lexer = CDSLProgram.Lexer(input: script)
            let (tokens, lexErrors) = lexer.tokenize()
            var parser = CDSLProgram.Parser(tokens: tokens)
            let (program, parseErrors) = parser.parse()

            let allErrors = lexErrors + parseErrors
            if !allErrors.isEmpty {
                throw CLILError.syntaxError(allErrors.map(\.description).joined(separator: "\n"))
            }

            guard let program else {
                throw CLILError.syntaxError("Failed to build CDSL AST")
            }

            // OpenAPIKit Validation Idiom: parse first, validate second
            try CDSLValidations.cdslDefault.validate(program)

            for stmt in program.statements {
                try await executeCDSL(stmt)
                if let onStepExecuted {
                    await onStepExecuted()
                }
            }
        }

        /// Compile, validate, and run the CLL script content.
        public func runCLL(_ script: String) async throws {
            var lexer = CLLProgram.Lexer(input: script)
            let (tokens, lexErrors) = lexer.tokenize()
            var parser = CLLProgram.Parser(tokens: tokens)
            let (program, parseErrors) = parser.parse()

            let allErrors = lexErrors + parseErrors
            if !allErrors.isEmpty {
                throw CLILError.syntaxError(allErrors.map(\.description).joined(separator: "\n"))
            }

            guard let program else {
                throw CLILError.syntaxError("Failed to build CLL AST")
            }

            // OpenAPIKit Validation Idiom: parse first, validate second
            try CLLValidations.cllDefault.validate(program)

            for stmt in program.statements {
                try await executeCLL(stmt)
                if let onStepExecuted {
                    await onStepExecuted()
                }
            }
        }

        private func executeCDSL(_ stmt: CDSLProgram.Statement) async throws {
            switch stmt {
            case let .dispatch(action, value):
                let clilValue = try convertCDSLValue(value)
                let clilAction = try convertCDSLAction(action)
                try await execute(.dispatch(clilAction, clilValue))
            case let .assertVM(property, op, expected):
                let clilExpected = try convertCDSLValue(expected)
                let clilOp = try convertCDSLOperator(op)
                try await execute(.assert(.vm, property, clilOp, clilExpected))
            case .awaitTasks:
                try await execute(.awaitTasks)
            }
        }

        private func executeCLL(_ stmt: CLLProgram.Statement) async throws {
            switch stmt {
            case let .device(deviceName, orientation, sizeClass):
                let clilDevice = try convertCLLDevice(deviceName)
                let clilOrientation = try convertCLLOrientation(orientation)
                let clilSizeClass = try convertCLLSizeClass(sizeClass)
                try await execute(.device(clilDevice, clilOrientation, clilSizeClass))
            case let .assertUI(property, op, expected):
                let clilExpected = try convertCLLValue(expected)
                let clilOp = try convertCLLOperator(op)
                try await execute(.assert(.ui, property, clilOp, clilExpected))
            }
        }

        private func convertCDSLValue(_ val: CDSLProgram.Value) throws -> CLILProgram.Value {
            switch val {
            case let .string(str): .string(str)
            case let .number(num): .number(num)
            case let .boolean(bool): .boolean(bool)
            case .nilValue: .nilValue
            case let .list(arr):
                try .list(arr.map { try convertCDSLValue($0) })
            }
        }

        private func convertCLLValue(_ val: CLLProgram.Value) throws -> CLILProgram.Value {
            switch val {
            case let .string(str): .string(str)
            case let .number(num): .number(num)
            case let .boolean(bool): .boolean(bool)
            case .nilValue: .nilValue
            }
        }

        private func convertCDSLAction(_ action: CDSLProgram.ActionName) throws -> CLILProgram.ActionName {
            guard let mapped = CLILProgram.ActionName(rawValue: action.rawValue) else {
                throw CLILError.runtimeError("Action \(action) not supported in CLIL")
            }
            return mapped
        }

        private func convertCDSLOperator(_ op: CDSLProgram.Operator) throws -> CLILProgram.Operator {
            guard let mapped = CLILProgram.Operator(rawValue: op.rawValue) else {
                throw CLILError.runtimeError("Operator \(op) not supported in CLIL")
            }
            return mapped
        }

        private func convertCLLOperator(_ op: CLLProgram.Operator) throws -> CLILProgram.Operator {
            guard let mapped = CLILProgram.Operator(rawValue: op.rawValue) else {
                throw CLILError.runtimeError("Operator \(op) not supported in CLIL")
            }
            return mapped
        }

        private func convertCLLDevice(_ device: CLLProgram.DeviceName) throws -> CLILProgram.DeviceName {
            guard let mapped = CLILProgram.DeviceName(rawValue: device.rawValue) else {
                throw CLILError.runtimeError("Device \(device) not supported in CLIL")
            }
            return mapped
        }

        private func convertCLLOrientation(_ orientation: CLLProgram.Orientation) throws -> CLILProgram.Orientation {
            guard let mapped = CLILProgram.Orientation(rawValue: orientation.rawValue) else {
                throw CLILError.runtimeError("Orientation \(orientation) not supported in CLIL")
            }
            return mapped
        }

        private func convertCLLSizeClass(_ sizeClass: CLLProgram.SizeClass) throws -> CLILProgram.SizeClass {
            guard let mapped = CLILProgram.SizeClass(rawValue: sizeClass.rawValue) else {
                throw CLILError.runtimeError("Size class \(sizeClass) not supported in CLIL")
            }
            return mapped
        }

        private func updateUIState() {
            if ui.device == .Mac || (ui.device == .iPad && ui.sizeClass == .regular) {
                ui.navigationStackDepth = 0
                ui.activeView = .splitView
            } else {
                // iPhone or iPad compact navigation stack behavior
                if let docState = frameworksVM?.documentState, case .loaded = docState {
                    ui.activeView = .reader
                    ui.navigationStackDepth = 3
                } else if frameworksVM?.selectedFramework != nil {
                    ui.activeView = .documents
                    ui.navigationStackDepth = 2
                } else if frameworksVM?.selectedSource != nil {
                    ui.activeView = .frameworks
                    ui.navigationStackDepth = 1
                } else {
                    ui.activeView = .databases
                    ui.navigationStackDepth = 0
                }
            }
        }

        private func parseSource(_ string: String) throws -> Model.Source? {
            if string.lowercased() == "nil" { return nil }
            for src in Model.Source.allCases {
                if src.rawValue == string || src.scheme == string { return src }
            }
            return Model.Source(rawValue: string)
        }

        private func execute(_ stmt: CLILProgram.Statement) async throws {
            switch stmt {
            case let .device(name, orientation, sizeClass):
                ui.device = name
                ui.orientation = orientation
                ui.sizeClass = sizeClass
                updateUIState()

            case let .dispatch(action, value):
                switch action {
                case .onAppeared:
                    frameworksVM?.onAppeared()
                case .onRetried:
                    frameworksVM?.onRetried()
                case .selectSource:
                    if case .nilValue = value {
                        frameworksVM?.selectSource(nil)
                    } else {
                        let sourceStr = try value.asString()
                        let source = try parseSource(sourceStr)
                        frameworksVM?.selectSource(source)
                    }
                    updateUIState()
                case .selectFramework:
                    if case .nilValue = value {
                        frameworksVM?.selectFramework(nil)
                    } else {
                        let id = try value.asString()
                        frameworksVM?.selectFramework(id)
                    }
                    updateUIState()
                case .selectDocument:
                    let uriStr = try value.asString()
                    guard let uri = Model.DocURI(uriStr) else {
                        throw CLILError.runtimeError("Invalid URI: \(uriStr)")
                    }
                    frameworksVM?.selectDocument(uri)
                    updateUIState()
                case .openDocument:
                    let uriStr = try value.asString()
                    guard let uri = Model.DocURI(uriStr) else {
                        throw CLILError.runtimeError("Invalid URI: \(uriStr)")
                    }
                    frameworksVM?.openDocument(uri)
                    updateUIState()
                case .search:
                    let text = try value.asString()
                    searchVM?.text = text
                    searchVM?.run()
                case .toggleSource:
                    let sourceStr = try value.asString()
                    guard let source = try parseSource(sourceStr) else {
                        throw CLILError.runtimeError("Invalid source: \(sourceStr)")
                    }
                    searchVM?.toggle(source)
                case .changeLimit:
                    let limit = try value.asInt()
                    searchVM?.limit = limit
                case .resizeText:
                    let dir = try value.asString()
                    if dir == "larger" {
                        Model.ReaderTextSize.larger()
                    } else if dir == "smaller" {
                        Model.ReaderTextSize.smaller()
                    } else {
                        throw CLILError.runtimeError("Invalid resize direction: \(dir)")
                    }
                }

            case let .assert(target, propertyStr, op, expected):
                let property: AssertProperty
                switch target {
                case .vm:
                    guard let vmProp = CDSLProgram.VMProperty(rawValue: propertyStr) else {
                        throw CLILError.runtimeError("Unknown VM property '\(propertyStr)'")
                    }
                    property = .vm(vmProp)
                case .ui:
                    guard let uiProp = CLLProgram.UIProperty(rawValue: propertyStr) else {
                        throw CLILError.runtimeError("Unknown UI property '\(propertyStr)'")
                    }
                    property = .ui(uiProp)
                }
                let actualValue = try getActualValue(property)
                try performAssert(actual: actualValue, expected: expected, op: op, property: propertyStr)

            case .awaitTasks:
                for _ in 0 ..< 10 {
                    await Task.yield()
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
                updateUIState()
            }
        }

        private func getActualValue(_ property: AssertProperty) throws -> CLILProgram.Value {
            switch property {
            case let .ui(uiProp):
                switch uiProp {
                case .device:
                    return .string(ui.device.rawValue)
                case .orientation:
                    return .string(ui.orientation.rawValue)
                case .sizeClass:
                    return .string(ui.sizeClass.rawValue)
                case .showsSidebarList:
                    return .boolean(ui.showsSidebarList)
                case .showsDetailPane:
                    return .boolean(ui.showsDetailPane)
                case .navigationStackDepth:
                    return .number(ui.navigationStackDepth)
                case .activeView:
                    return .string(ui.activeView.rawValue)
                }

            case let .vm(vmProp):
                guard let frameworksVM else {
                    throw CLILError.runtimeError("Framework VM is nil during assertion on VM property")
                }
                switch vmProp {
                case .activeSource:
                    if let src = frameworksVM.selectedSource {
                        return .string(src.rawValue)
                    } else {
                        return .nilValue
                    }
                case .selectedFrameworkID:
                    if let framework = frameworksVM.selectedFramework {
                        return .string(framework.id)
                    } else {
                        return .nilValue
                    }
                case .isLoading:
                    return .boolean(frameworksVM.isLoading)
                case .isLoadingDocument:
                    return .boolean(frameworksVM.isLoadingDocument)
                case .errorMessage:
                    if let msg = frameworksVM.errorMessage {
                        return .string(msg)
                    } else {
                        return .nilValue
                    }
                case .documentState:
                    switch frameworksVM.documentState {
                    case .empty: return .string("empty")
                    case .loading: return .string("loading")
                    case .loaded: return .string("loaded")
                    case .failed: return .string("failed")
                    }
                case .selectedMarkdown:
                    if let md = frameworksVM.selectedMarkdown {
                        return .string(md)
                    } else {
                        return .nilValue
                    }
                case .results:
                    if let searchVM {
                        return .list(searchVM.results.map { .string($0.title) })
                    } else {
                        return .list([])
                    }
                case .documents:
                    return .list(frameworksVM.documents.map { .string($0.title) })
                case .state:
                    switch frameworksVM.state {
                    case .idle: return .string("idle")
                    case .loading: return .string("loading")
                    case .loaded: return .string("loaded")
                    case .failed: return .string("failed")
                    }
                case .text:
                    if let searchVM {
                        return .string(searchVM.text)
                    } else {
                        return .nilValue
                    }
                }
            }
        }

        private func performAssert(actual: CLILProgram.Value, expected: CLILProgram.Value, op: CLILProgram.Operator, property: String) throws {
            switch op {
            case .eq:
                if actual != expected {
                    throw CLILError.assertionFailed("Assertion failed: \(property) (\(actual)) == \(expected)")
                }
            case .ne:
                if actual == expected {
                    throw CLILError.assertionFailed("Assertion failed: \(property) (\(actual)) != \(expected)")
                }
            case .contains:
                guard case let .list(actualList) = actual else {
                    throw CLILError.runtimeError("Cannot perform contains check on non-list value: \(actual)")
                }
                if !actualList.contains(expected) {
                    throw CLILError.assertionFailed("Assertion failed: \(property) (\(actual)) does not contain \(expected)")
                }
            case .shows:
                guard case let .boolean(actualBool) = actual else {
                    throw CLILError.runtimeError("Cannot perform shows check on non-boolean: \(actual)")
                }
                if !actualBool {
                    throw CLILError.assertionFailed("Assertion failed: \(property) shows (expected true, got false)")
                }
            case .hides:
                guard case let .boolean(actualBool) = actual else {
                    throw CLILError.runtimeError("Cannot perform hides check on non-boolean: \(actual)")
                }
                if actualBool {
                    throw CLILError.assertionFailed("Assertion failed: \(property) hides (expected false, got true)")
                }
            }
        }
    }
}

// MARK: - Lexer

private struct Token: Equatable {
    enum Kind: Equatable {
        case device, `in`, with
        case dispatch, assert, await, tasks
        case identifier(String)
        case string(String)
        case number(Int)
        case boolean(Bool)
        case op(String)
        case lparen, rparen, lbracket, rbracket, comma
        case nilLiteral
        case eof

        var identifierString: String? {
            switch self {
            case let .identifier(str): str
            case .device: "device"
            case .in: "in"
            case .with: "with"
            case .dispatch: "dispatch"
            case .assert: "assert"
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

    let kind: Kind
    let line: Int
    let column: Int
}

private struct Lexer {
    let input: String
    private var index: String.Index
    private var line = 1
    private var column = 1

    init(input: String) {
        self.input = input
        index = input.startIndex
    }

    mutating func nextToken() throws -> Token {
        skipWhitespaceAndComments()

        guard index < input.endIndex else {
            return Token(kind: .eof, line: line, column: column)
        }

        let char = input[index]
        let currentLine = line
        let currentColumn = column

        if char == "(" {
            advance()
            return Token(kind: .lparen, line: currentLine, column: currentColumn)
        } else if char == ")" {
            advance()
            return Token(kind: .rparen, line: currentLine, column: currentColumn)
        } else if char == "[" {
            advance()
            return Token(kind: .lbracket, line: currentLine, column: currentColumn)
        } else if char == "]" {
            advance()
            return Token(kind: .rbracket, line: currentLine, column: currentColumn)
        } else if char == "," {
            advance()
            return Token(kind: .comma, line: currentLine, column: currentColumn)
        }

        if char == "=" {
            advance()
            if index < input.endIndex, input[index] == "=" {
                advance()
                return Token(kind: .op("=="), line: currentLine, column: currentColumn)
            }
            throw Presentation.CLILError.lexicalError("Unexpected '=' character at line \(currentLine), column \(currentColumn)")
        } else if char == "!" {
            advance()
            if index < input.endIndex, input[index] == "=" {
                advance()
                return Token(kind: .op("!="), line: currentLine, column: currentColumn)
            }
            throw Presentation.CLILError.lexicalError("Unexpected '!' character at line \(currentLine), column \(currentColumn)")
        }

        if char == "\"" {
            advance()
            var strValue = ""
            while index < input.endIndex, input[index] != "\"" {
                strValue.append(input[index])
                advance()
            }
            guard index < input.endIndex, input[index] == "\"" else {
                throw Presentation.CLILError.lexicalError("Unterminated string literal at line \(currentLine), column \(currentColumn)")
            }
            advance()
            return Token(kind: .string(strValue), line: currentLine, column: currentColumn)
        }

        if char.isNumber {
            var numStr = ""
            while index < input.endIndex, input[index].isNumber {
                numStr.append(input[index])
                advance()
            }
            if let num = Int(numStr) {
                return Token(kind: .number(num), line: currentLine, column: currentColumn)
            }
            throw Presentation.CLILError.lexicalError("Invalid number format '\(numStr)' at line \(currentLine), column \(currentColumn)")
        }

        if char.isLetter || char == "_" {
            var ident = ""
            while index < input.endIndex, input[index].isLetter || input[index].isNumber || input[index] == "_" || input[index] == "-" {
                ident.append(input[index])
                advance()
            }

            switch ident {
            case "device": return Token(kind: .device, line: currentLine, column: currentColumn)
            case "in": return Token(kind: .in, line: currentLine, column: currentColumn)
            case "with": return Token(kind: .with, line: currentLine, column: currentColumn)
            case "dispatch": return Token(kind: .dispatch, line: currentLine, column: currentColumn)
            case "assert": return Token(kind: .assert, line: currentLine, column: currentColumn)
            case "await": return Token(kind: .await, line: currentLine, column: currentColumn)
            case "tasks": return Token(kind: .tasks, line: currentLine, column: currentColumn)
            case "nil": return Token(kind: .nilLiteral, line: currentLine, column: currentColumn)
            case "true": return Token(kind: .boolean(true), line: currentLine, column: currentColumn)
            case "false": return Token(kind: .boolean(false), line: currentLine, column: currentColumn)
            case "contains", "shows", "hides":
                return Token(kind: .op(ident), line: currentLine, column: currentColumn)
            default:
                return Token(kind: .identifier(ident), line: currentLine, column: currentColumn)
            }
        }

        let badChar = input[index]
        advance()
        throw Presentation.CLILError.lexicalError("Unexpected character '\(badChar)' at line \(currentLine), column \(currentColumn)")
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

// MARK: - Parser

private struct Parser {
    private var lexer: Lexer
    private var currentToken: Token

    init(lexer: Lexer) {
        self.lexer = lexer
        var tempLexer = lexer
        currentToken = (try? tempLexer.nextToken()) ?? Token(kind: .eof, line: 1, column: 1)
        self.lexer = tempLexer
    }

    mutating func parse() throws -> Presentation.CLILProgram {
        var statements: [Presentation.CLILProgram.Statement] = []
        while currentToken.kind != .eof {
            try statements.append(parseStatement())
        }
        return Presentation.CLILProgram(statements: statements)
    }

    private mutating func consume(_ kind: Token.Kind) throws {
        if currentToken.kind == kind {
            currentToken = try lexer.nextToken()
        } else {
            throw Presentation.CLILError.syntaxError("Expected token \(kind), got \(currentToken.kind) at line \(currentToken.line), column \(currentToken.column)")
        }
    }

    private mutating func parseStatement() throws -> Presentation.CLILProgram.Statement {
        switch currentToken.kind {
        case .device:
            try consume(.device)
            guard let deviceNameStr = currentToken.kind.identifierString,
                  let deviceName = Presentation.CLILProgram.DeviceName(rawValue: deviceNameStr)
            else {
                throw Presentation.CLILError.syntaxError("Expected device name, got \(currentToken.kind) at line \(currentToken.line)")
            }
            try consume(currentToken.kind)

            try consume(.in)
            guard let orientationStr = currentToken.kind.identifierString,
                  let orientation = Presentation.CLILProgram.Orientation(rawValue: orientationStr)
            else {
                throw Presentation.CLILError.syntaxError("Expected orientation, got \(currentToken.kind) at line \(currentToken.line)")
            }
            try consume(currentToken.kind)

            try consume(.with)
            guard let sizeClassStr = currentToken.kind.identifierString,
                  let sizeClass = Presentation.CLILProgram.SizeClass(rawValue: sizeClassStr)
            else {
                throw Presentation.CLILError.syntaxError("Expected size class, got \(currentToken.kind) at line \(currentToken.line)")
            }
            try consume(currentToken.kind)

            return .device(deviceName, orientation, sizeClass)

        case .dispatch:
            try consume(.dispatch)
            guard case let .identifier(actionNameStr) = currentToken.kind,
                  let action = Presentation.CLILProgram.ActionName(rawValue: actionNameStr)
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
            let target: Presentation.CLILProgram.AssertTarget
            guard let targetStr = currentToken.kind.identifierString else {
                throw Presentation.CLILError.syntaxError("Expected assert target identifier, got \(currentToken.kind) at line \(currentToken.line)")
            }
            if targetStr == "vm" {
                target = .vm
            } else if targetStr == "ui" {
                target = .ui
            } else {
                throw Presentation.CLILError.syntaxError("Expected assert target (vm, ui), got \(targetStr) at line \(currentToken.line)")
            }
            try consume(currentToken.kind)

            guard let property = currentToken.kind.identifierString else {
                throw Presentation.CLILError.syntaxError("Expected property identifier, got \(currentToken.kind) at line \(currentToken.line)")
            }
            try consume(currentToken.kind)

            guard case let .op(opStr) = currentToken.kind,
                  let op = Presentation.CLILProgram.Operator(rawValue: opStr)
            else {
                throw Presentation.CLILError.syntaxError("Expected operator, got \(currentToken.kind) at line \(currentToken.line)")
            }
            try consume(currentToken.kind)

            let expected = try parseValue()
            return .assert(target, property, op, expected)

        case .await:
            try consume(.await)
            try consume(.tasks)
            return .awaitTasks

        default:
            throw Presentation.CLILError.syntaxError("Unexpected token \(currentToken.kind) starting statement at line \(currentToken.line)")
        }
    }

    private mutating func parseValue() throws -> Presentation.CLILProgram.Value {
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
            var elements: [Presentation.CLILProgram.Value] = []
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
