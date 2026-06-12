import Foundation
import Lexer
import SharedModels

public class Parser {
    public let tokens: [Token]
    public var pos = 0

    /// Physical-file writes deferred until the whole template is parsed. A node's content must land at its
    /// SOURCE path, which for a Definition node is given by its `Path` and resolved against the complete
    /// `Definitions` metadata. Resolving inline would be wrong because units are parsed before the
    /// top-level `Definitions`, so the source lookup would miss and the file would be materialised at the
    /// Definition's OUTPUT path (an instantiation target, not a template source file).
    private var pendingFiles: [(nodePath: String, explicitPath: String?, content: String, isBinary: Bool)] = []

    /// Non-nil while `parseRecovering` runs: syntax errors are collected here and the parser resynchronizes
    /// instead of aborting (Dragon Book §4.1.4 panic mode). Nil in strict mode, where the first error throws
    /// exactly as before, so the compile and decompile paths never build from broken source.
    private var recoveryErrors: [SyntaxError]?

    /// The concrete syntax tree of the last parse: every structural construct with the token range it
    /// spans, built alongside the semantic bundle in the same pass. Available after `parse()` or
    /// `parseRecovering()`; on a recovered parse, partial constructs are present with the spans they
    /// actually covered before resynchronization.
    public private(set) var syntaxTree: SyntaxNode?
    private var syntaxStack: [SyntaxNode] = []

    private func beginNode(_ kind: SyntaxNode.Kind, startingAt start: Int) {
        syntaxStack.append(SyntaxNode(kind: kind, tokenRange: start ..< start))
    }

    private func endNode() {
        guard var node = syntaxStack.popLast() else { return }
        node.extend(to: pos)
        if syntaxStack.isEmpty {
            syntaxTree = node
        } else {
            syntaxStack[syntaxStack.count - 1].append(node)
        }
    }

    /// Close any constructs left open by a thrown error (their spans end where parsing stopped), so the
    /// tree stays balanced across panic-mode recovery and partial constructs remain visible to an editor.
    private func unwindSyntax(to depth: Int) {
        while syntaxStack.count > depth {
            endNode()
        }
    }

    public init(tokens: [Token]) {
        self.tokens = tokens
    }

    /// Recovering parse: collects EVERY syntax error in one pass, resynchronizing after each via panic mode
    /// (skip tokens to a synchronizing set; §4.4.5). Returns the best-effort bundle, or nil when the error
    /// was structural enough to abort (e.g. a broken template header). Correct input takes the exact same
    /// path as `parse()` and pays no overhead.
    public func parseRecovering() -> (bundle: XcodeTemplateBundle?, errors: [SyntaxError]) {
        recoveryErrors = []
        defer { recoveryErrors = nil }
        var bundle: XcodeTemplateBundle?
        var errors: [SyntaxError] = []
        do {
            bundle = try parse()
            errors = recoveryErrors ?? []
        } catch let error as SyntaxError {
            unwindSyntax(to: 0) // flush the partial tree so the editor still gets spans
            errors = recoveryErrors ?? []
            errors.append(error)
        } catch {
            unwindSyntax(to: 0)
            errors = recoveryErrors ?? []
            errors.append(SyntaxError(line: 1, column: 1, kind: .wrapped(error.localizedDescription)))
        }
        // The editor invariant: the root spans the WHOLE buffer. A throw can leave the offending
        // token outside the root's consumed range (e.g. a doubly-unterminated header); growing the
        // root to cover every token keeps outlines and fold ranges anchored to the full document.
        // A clean parse already spans everything, so this is a no-op there.
        if !tokens.isEmpty {
            syntaxTree?.extend(to: tokens.count)
        }
        // Dedupe identical diagnostics (recovery near EOF can detect the same condition twice).
        var seen = Set<String>()
        let unique = errors.filter { seen.insert("\($0.line):\($0.column):\($0.message)").inserted }
        return (bundle, unique)
    }

    /// What panic-mode recovery decided (the two actions of the book's Fig 4.22 synchronizing table):
    /// `resumed` stops at a token in FIRST of the construct's items (or its closing brace) and the loop
    /// continues; `popped` stops at a token that can only start a HIGHER-level construct, so the current
    /// nonterminal must be closed (popped) and control returned to the enclosing loop, which parses that
    /// token correctly instead of mis-attaching everything after it.
    enum RecoveryAction {
        case resumed
        case popped
    }

    /// Panic-mode recovery (§4.4.5): in strict mode rethrows; in recovering mode records the error, then
    /// skips tokens until one of the synchronizing sets. `resumeOn` is FIRST(item) plus the closing brace
    /// (derived from the grammar's FIRST/FOLLOW sets, see docs/GRAMMAR.md); `popOn` holds the starters of
    /// enclosing constructs (the book's heuristic 2: add higher-level beginners to a lower construct's
    /// set, realized as pop rather than as a spurious re-error). The progress guard (consume at least one
    /// token when the failing item consumed none) makes an infinite loop impossible: every recovery action
    /// consumes input, exactly the book's termination condition.
    private func recover(
        _ error: SyntaxError,
        itemStart: Int,
        resumeOn isResume: (Token) -> Bool,
        popOn isPop: ((Token) -> Bool)? = nil,
    ) throws -> RecoveryAction {
        guard recoveryErrors != nil else { throw error }
        recoveryErrors?.append(error)
        // A pop token at the error position pops WITHOUT consuming: the enclosing loop will parse it.
        // That is still progress by the book's own termination rule (an input symbol consumed OR the
        // stack shortened), and consuming it here would skip into the enclosing construct's body.
        if let isPop, let tok = peek(), isPop(tok) { return .popped }
        // Otherwise guarantee progress by consuming at least one token, then scan for a sync token.
        if pos == itemStart { pos += 1 }
        while let tok = peek() {
            if isResume(tok) { return .resumed }
            if let isPop, isPop(tok) { return .popped }
            pos += 1
        }
        return .resumed // at EOF the loop condition ends the construct
    }

    public func peek() -> Token? {
        pos < tokens.count ? tokens[pos] : nil
    }

    @discardableResult
    public func consume(_ expectedType: TokenType? = nil) throws -> Token {
        guard let tok = peek() else {
            let last = tokens.last
            throw SyntaxError(line: last?.line ?? 1, column: (last?.column ?? 0) + 1, kind: .unexpectedEndOfFile)
        }
        if let type = expectedType, tok.type != type {
            throw SyntaxError(line: tok.line, column: tok.column, kind: .expectedToken(expected: "\(type)", foundType: "\(tok.type)", foundValue: tok.value))
        }
        pos += 1
        return tok
    }

    public func parse() throws -> XcodeTemplateBundle {
        syntaxTree = nil
        syntaxStack = []
        beginNode(.template, startingAt: pos)
        let rootTok = try consume(.identifier)
        if rootTok.value != "template" {
            throw SyntaxError(line: rootTok.line, column: rootTok.column, kind: .rootMustBeTemplate(found: rootTok.value))
        }

        let templateId = try consume(.string).value
        try consume(.lbrace)

        var bundle = XcodeTemplateBundle(name: "", identifier: templateId, metadata: [:], files: [:])

        while let tok = peek(), tok.type != .rbrace {
            let itemStart = pos
            let syntaxDepth = syntaxStack.count
            do {
                try parseTemplateBodyItem(into: &bundle)
            } catch let error as SyntaxError {
                unwindSyntax(to: syntaxDepth)
                _ = try recover(error, itemStart: itemStart, resumeOn: { tok in
                    tok.type == .letKeyword || tok.type == .rbrace
                        || (tok.type == .identifier && ["option", "node", "directory"].contains(tok.value))
                })
            }
        }

        try consume(.rbrace)
        unwindSyntax(to: 0)

        // The whole input must be consumed (section 4.4.1: success means the procedure scanned the ENTIRE
        // input). Trailing tokens after the template closes are an error, not silently ignored. One
        // exception in recovering mode: when a pop already recorded an error, its construct's orphaned
        // closing braces remain in the stream; reporting those again would be avalanche, so brace-only
        // debris after a recorded error is consumed silently.
        if let trailing = peek() {
            let alreadyErrored = !(recoveryErrors ?? []).isEmpty
            let braceOnlyDebris = tokens[pos...].allSatisfy { $0.type == .rbrace }
            if recoveryErrors != nil, alreadyErrored, braceOnlyDebris {
                pos = tokens.count
            } else {
                let error = SyntaxError(line: trailing.line, column: trailing.column, kind: .trailingInput(found: trailing.value))
                if recoveryErrors != nil {
                    recoveryErrors?.append(error)
                    pos = tokens.count
                } else {
                    throw error
                }
            }
        }

        // Now that all metadata is parsed, materialise the deferred physical files. A node keyed by a
        // Definition OUTPUT path is written at the SOURCE path the Definition references, never at the
        // output path. This keeps the recreated bundle to the template's actual source files and not the
        // per-option instantiation targets.
        for pending in pendingFiles {
            var physicalPath = pending.nodePath
            if let explicit = pending.explicitPath {
                physicalPath = explicit
            } else if case let .dictionary(defs) = bundle.metadata["Definitions"],
                      case let .dictionary(def) = defs[pending.nodePath],
                      case let .string(source) = def["Path"]
            {
                physicalPath = source
            }
            bundle.files[physicalPath] = FileInfo(type: pending.isBinary ? "binary" : "text", content: pending.content)
        }

        return bundle
    }

    private func parseTemplateBodyItem(into bundle: inout XcodeTemplateBundle) throws {
        guard let tok = peek() else { return }
        let startPos = pos

        if tok.type == .letKeyword {
            beginNode(.letBinding, startingAt: startPos)
            defer { endNode() }
            _ = try consume(.letKeyword)
            let keyTok = peek()
            let key: String
            if keyTok?.type == .identifier {
                key = try consume(.identifier).value
            } else if keyTok?.type == .string {
                key = try consume(.string).value
            } else if keyTok?.type == .boolean {
                key = try consume(.boolean).value
            } else {
                throw SyntaxError(line: keyTok?.line ?? tokens.last?.line ?? 1, column: keyTok?.column ?? ((tokens.last?.column ?? 0) + 1), kind: .expectedKeyAfterLet)
            }
            try consume(.equals)
            let val = try parseValue()
            bundle.metadata[key] = val
        } else if tok.type == .identifier {
            let itok = try consume(.identifier)
            let key = itok.value
            if key == "option" || key == "node" {
                try parseBlockStructure(blockName: key, parentBundle: &bundle, startTokenIndex: startPos)
            } else if key == "directory" {
                beginNode(.directory, startingAt: startPos)
                defer { endNode() }
                try bundle.emptyDirectories.append(consume(.string).value)
            } else {
                throw SyntaxError(line: itok.line, column: itok.column, kind: .expectedTemplateItem(found: key))
            }
        } else {
            throw SyntaxError(line: tok.line, column: tok.column, kind: .unexpectedToken(found: tok.value))
        }
    }

    private func parseBlockStructure(blockName: String, parentBundle: inout XcodeTemplateBundle, startTokenIndex: Int) throws {
        beginNode(blockName == "option" ? .option : .node, startingAt: startTokenIndex)
        defer { endNode() }
        if blockName == "option" {
            let optId = try consume(.string).value
            try consume(.lbrace)

            var opt: [String: PropertyListValue] = ["Identifier": .string(optId)]
            var optionPopped = false

            while let tok = peek(), tok.type != .rbrace {
                let optionItemStart = pos
                do {
                    if tok.type == .letKeyword {
                        beginNode(.letBinding, startingAt: optionItemStart)
                        defer { endNode() }
                        _ = try consume(.letKeyword)
                        let keyTok = peek()
                        let key: String
                        if keyTok?.type == .identifier {
                            key = try consume(.identifier).value
                        } else if keyTok?.type == .string {
                            key = try consume(.string).value
                        } else if keyTok?.type == .boolean {
                            key = try consume(.boolean).value
                        } else {
                            throw SyntaxError(
                                line: keyTok?.line ?? tokens.last?.line ?? 1,
                                column: keyTok?.column ?? ((tokens.last?.column ?? 0) + 1),
                                kind: .expectedKeyAfterLetInOption,
                            )
                        }
                        try consume(.equals)
                        opt[key] = try parseValue()
                    } else if tok.type == .identifier, tok.value == "unit" {
                        beginNode(.unit, startingAt: optionItemStart)
                        defer { endNode() }
                        _ = try consume(.identifier)
                        let unitVal = try consume(.string).value
                        try consume(.lbrace)

                        var unitMetadata: [String: PropertyListValue] = [:]
                        var unitPopped = false

                        while let utok = peek(), utok.type != .rbrace {
                            let unitItemStart = pos
                            do {
                                try parseUnitBodyItem(metadata: &unitMetadata, rootBundle: &parentBundle)
                            } catch let error as SyntaxError {
                                let action = try recover(error, itemStart: unitItemStart, resumeOn: { tok in
                                    tok.type == .letKeyword || tok.type == .rbrace
                                        || (tok.type == .identifier && tok.value == "node")
                                }, popOn: { tok in
                                    tok.type == .identifier && ["unit", "option", "directory"].contains(tok.value)
                                })
                                if action == .popped { unitPopped = true
                                    break
                                }
                            }
                        }
                        if !unitPopped { try consume(.rbrace) }

                        // Check for _isEmptyArray flag
                        var isEmptyArray = false
                        if case let .boolean(b) = unitMetadata["_isEmptyArray"], b {
                            isEmptyArray = true
                        }

                        // Check for _isArray flag
                        var isArray = false
                        if case let .boolean(b) = unitMetadata["_isArray"], b {
                            isArray = true
                            unitMetadata.removeValue(forKey: "_isArray")
                        }

                        // Store unit (supporting arrays of units)
                        if case var .dictionary(units) = opt["Units"] {
                            if let existing = units[unitVal] {
                                if case var .array(arr) = existing {
                                    arr.append(.dictionary(unitMetadata))
                                    units[unitVal] = .array(arr)
                                } else {
                                    units[unitVal] = .array([existing, .dictionary(unitMetadata)])
                                }
                            } else {
                                if isEmptyArray {
                                    units[unitVal] = .array([])
                                } else if isArray {
                                    units[unitVal] = .array([.dictionary(unitMetadata)])
                                } else {
                                    units[unitVal] = .dictionary(unitMetadata)
                                }
                            }
                            opt["Units"] = .dictionary(units)
                        } else {
                            if isEmptyArray {
                                opt["Units"] = .dictionary([unitVal: .array([])])
                            } else if isArray {
                                opt["Units"] = .dictionary([unitVal: .array([.dictionary(unitMetadata)])])
                            } else {
                                opt["Units"] = .dictionary([unitVal: .dictionary(unitMetadata)])
                            }
                        }
                    } else {
                        throw SyntaxError(line: tok.line, column: tok.column, kind: .expectedOptionItem(foundType: "\(tok.type)", foundValue: tok.value))
                    }
                } catch let error as SyntaxError {
                    let action = try recover(error, itemStart: optionItemStart, resumeOn: { tok in
                        tok.type == .letKeyword || tok.type == .rbrace
                            || (tok.type == .identifier && tok.value == "unit")
                    }, popOn: { tok in
                        tok.type == .identifier && ["option", "node", "directory"].contains(tok.value)
                    })
                    if action == .popped { optionPopped = true
                        break
                    }
                }
            }
            if !optionPopped { try consume(.rbrace) }

            // Append option
            if case var .array(opts) = parentBundle.metadata["Options"] {
                opts.append(.dictionary(opt))
                parentBundle.metadata["Options"] = .array(opts)
            } else {
                parentBundle.metadata["Options"] = .array([.dictionary(opt)])
            }

        } else if blockName == "node" {
            let nodePath = try consume(.string).value
            try consume(.lbrace)

            var fileContent: String? = nil
            var isBinary = false
            var fileSource: String? = nil
            var isStringDefinition = false
            var nodeMetadata: [String: PropertyListValue] = [:]

            var nodePopped = false
            while let tok = peek(), tok.type != .rbrace {
                let nodeItemStart = pos
                do {
                    beginNode(.letBinding, startingAt: nodeItemStart)
                    defer { endNode() }
                    try consume(.letKeyword)
                    let keyTok = peek()
                    let key: String
                    if keyTok?.type == .identifier {
                        key = try consume(.identifier).value
                    } else if keyTok?.type == .string {
                        key = try consume(.string).value
                    } else if keyTok?.type == .boolean {
                        key = try consume(.boolean).value
                    } else {
                        throw SyntaxError(
                            line: keyTok?.line ?? tokens.last?.line ?? 1,
                            column: keyTok?.column ?? ((tokens.last?.column ?? 0) + 1),
                            kind: .expectedKeyAfterLetInNode,
                        )
                    }
                    try consume(.equals)

                    if key == "content" {
                        if case let .string(c) = try parseValue() {
                            fileContent = c
                        }
                    } else if key == "source" {
                        if case let .string(s) = try parseValue() {
                            fileSource = s
                        }
                    } else if key == "binary" {
                        if case let .boolean(b) = try parseValue() {
                            isBinary = b
                        }
                    } else if key == "_isString" {
                        if case let .boolean(b) = try parseValue() {
                            isStringDefinition = b
                        }
                    } else {
                        nodeMetadata[key] = try parseValue()
                    }
                } catch let error as SyntaxError {
                    let action = try recover(error, itemStart: nodeItemStart, resumeOn: { tok in
                        tok.type == .letKeyword || tok.type == .rbrace
                    }, popOn: { tok in
                        tok.type == .identifier && ["node", "unit", "option", "directory"].contains(tok.value)
                    })
                    if action == .popped { nodePopped = true
                        break
                    }
                }
            }
            if !nodePopped { try consume(.rbrace) }

            if isStringDefinition {
                let finalVal = PropertyListValue.string(fileContent ?? "")
                if case var .dictionary(defs) = parentBundle.metadata["Definitions"] {
                    defs[nodePath] = finalVal
                    parentBundle.metadata["Definitions"] = .dictionary(defs)
                } else {
                    parentBundle.metadata["Definitions"] = .dictionary([nodePath: finalVal])
                }
            } else {
                if !nodeMetadata.isEmpty {
                    if case var .dictionary(defs) = parentBundle.metadata["Definitions"] {
                        if case var .dictionary(defNode) = defs[nodePath] {
                            for (k, v) in nodeMetadata {
                                defNode[k] = v
                            }
                            defs[nodePath] = .dictionary(defNode)
                        } else {
                            defs[nodePath] = .dictionary(nodeMetadata)
                        }
                        parentBundle.metadata["Definitions"] = .dictionary(defs)
                    } else {
                        parentBundle.metadata["Definitions"] = .dictionary([nodePath: .dictionary(nodeMetadata)])
                    }
                }

                // Defer the physical-file write; the source path is resolved in parse() against the
                // complete Definitions metadata (see pendingFiles).
                if let content = fileContent ?? fileSource {
                    let explicit: String? = if case let .string(p) = nodeMetadata["Path"] { p } else { nil }
                    pendingFiles.append((nodePath: nodePath, explicitPath: explicit, content: content, isBinary: isBinary))
                }
            }

        } else {
            throw SyntaxError(line: tokens.last?.line ?? 1, column: tokens.last?.column ?? 1, kind: .unknownBlockType(found: blockName))
        }
    }

    private func parseUnitBodyItem(metadata: inout [String: PropertyListValue], rootBundle _: inout XcodeTemplateBundle) throws {
        guard let tok = peek() else {
            throw SyntaxError(line: tokens.last?.line ?? 1, column: (tokens.last?.column ?? 0) + 1, kind: .unexpectedEndOfFileInUnitBody)
        }
        let startPos = pos

        if tok.type == .letKeyword {
            beginNode(.letBinding, startingAt: startPos)
            defer { endNode() }
            _ = try consume(.letKeyword)
            let keyTok = peek()
            let key: String
            if keyTok?.type == .identifier {
                key = try consume(.identifier).value
            } else if keyTok?.type == .string {
                key = try consume(.string).value
            } else if keyTok?.type == .boolean {
                key = try consume(.boolean).value
            } else {
                throw SyntaxError(line: keyTok?.line ?? tokens.last?.line ?? 1, column: keyTok?.column ?? ((tokens.last?.column ?? 0) + 1), kind: .expectedKeyAfterLetInUnit)
            }
            try consume(.equals)
            metadata[key] = try parseValue()
        } else if tok.type == .identifier, tok.value == "node" {
            beginNode(.node, startingAt: startPos)
            defer { endNode() }
            _ = try consume(.identifier)
            let nodePath = try consume(.string).value
            try consume(.lbrace)

            var fileContent: String? = nil
            var isBinary = false
            var isStringDefinition = false
            var nodeMetadata: [String: PropertyListValue] = [:]

            var unitNodePopped = false
            while let stok = peek(), stok.type != .rbrace {
                let bindingStart = pos
                do {
                    beginNode(.letBinding, startingAt: bindingStart)
                    defer { endNode() }
                    try consume(.letKeyword)
                    let subKeyTok = peek()
                    let subKey: String
                    if subKeyTok?.type == .identifier {
                        subKey = try consume(.identifier).value
                    } else if subKeyTok?.type == .string {
                        subKey = try consume(.string).value
                    } else if subKeyTok?.type == .boolean {
                        subKey = try consume(.boolean).value
                    } else {
                        throw SyntaxError(
                            line: subKeyTok?.line ?? tokens.last?.line ?? 1,
                            column: subKeyTok?.column ?? ((tokens.last?.column ?? 0) + 1),
                            kind: .expectedKeyAfterLetInUnitNode,
                        )
                    }
                    try consume(.equals)

                    if subKey == "content" {
                        if case let .string(c) = try parseValue() {
                            fileContent = c
                        }
                    } else if subKey == "binary" {
                        if case let .boolean(b) = try parseValue() {
                            isBinary = b
                        }
                    } else if subKey == "_isString" {
                        if case let .boolean(b) = try parseValue() {
                            isStringDefinition = b
                        }
                    } else {
                        nodeMetadata[subKey] = try parseValue()
                    }
                } catch let error as SyntaxError {
                    let action = try recover(error, itemStart: bindingStart, resumeOn: { tok in
                        tok.type == .letKeyword || tok.type == .rbrace
                    }, popOn: { tok in
                        tok.type == .identifier && ["node", "unit", "option", "directory"].contains(tok.value)
                    })
                    if action == .popped { unitNodePopped = true
                        break
                    }
                }
            }
            if !unitNodePopped { try consume(.rbrace) }

            if isStringDefinition {
                let finalVal = PropertyListValue.string(fileContent ?? "")
                if case var .dictionary(defs) = metadata["Definitions"] {
                    defs[nodePath] = finalVal
                    metadata["Definitions"] = .dictionary(defs)
                } else {
                    metadata["Definitions"] = .dictionary([nodePath: finalVal])
                }
            } else {
                if !nodeMetadata.isEmpty {
                    if case var .dictionary(defs) = metadata["Definitions"] {
                        if case var .dictionary(defNode) = defs[nodePath] {
                            for (k, v) in nodeMetadata {
                                defNode[k] = v
                            }
                            defs[nodePath] = .dictionary(defNode)
                        } else {
                            defs[nodePath] = .dictionary(nodeMetadata)
                        }
                        metadata["Definitions"] = .dictionary(defs)
                    } else {
                        metadata["Definitions"] = .dictionary([nodePath: .dictionary(nodeMetadata)])
                    }
                }

                // Defer the physical-file write; the source path is resolved in parse() against the
                // complete Definitions metadata. Resolving here misses, because the top-level Definitions
                // are parsed after the units, which is why definitions were being materialised at their
                // output paths.
                if let content = fileContent {
                    let explicit: String? = if case let .string(p) = nodeMetadata["Path"] { p } else { nil }
                    pendingFiles.append((nodePath: nodePath, explicitPath: explicit, content: content, isBinary: isBinary))
                }
            }
        } else {
            throw SyntaxError(line: tok.line, column: tok.column, kind: .expectedUnitItem(foundType: "\(tok.type)", foundValue: tok.value))
        }
    }

    /// Maximum container nesting inside one value. Real manifests stay in single digits
    /// (corpus-proven structural bounds); the limit exists because an editor buffer can contain
    /// ANYTHING, and a recursive-descent parser without a depth bound answers a 20,000-bracket
    /// paste with a stack overflow, which in-process means the whole IDE dies. Exceeding the bound
    /// is a positioned diagnostic like any other, not a crash. The bound must hold on a 512 KB
    /// worker-thread stack with debug-sized frames (the IDE analyzes off the main thread), which
    /// caps it well below what the main thread could survive; 64 is still an order of magnitude
    /// beyond any shipped manifest.
    private static let maximumValueDepth = 64
    private var valueDepth = 0

    private func parseValue() throws -> PropertyListValue {
        guard let tok = peek() else {
            throw SyntaxError(line: tokens.last?.line ?? 1, column: (tokens.last?.column ?? 0) + 1, kind: .unexpectedEndOfFileInValue)
        }
        guard valueDepth < Self.maximumValueDepth else {
            throw SyntaxError(line: tok.line, column: tok.column, kind: .nestingTooDeep(limit: Self.maximumValueDepth))
        }
        valueDepth += 1
        defer { valueDepth -= 1 }

        switch tok.type {
        case .string, .multilineString:
            _ = try consume()
            return .string(tok.value)
        case .boolean:
            _ = try consume()
            return .boolean(tok.value == "true")
        case .number:
            _ = try consume()
            // A lexeme with a fractional part or exponent is a real; otherwise an integer. An integer too
            // large for Int falls back to real rather than silently becoming 0.
            if tok.value.contains(".") || tok.value.lowercased().contains("e") {
                return .real(Double(tok.value) ?? 0)
            }
            if let integer = Int(tok.value) {
                return .integer(integer)
            }
            return .real(Double(tok.value) ?? 0)
        case .lbracket:
            _ = try consume(.lbracket)
            var arr: [PropertyListValue] = []
            while let t = peek(), t.type != .rbracket {
                try arr.append(parseValue())
                if peek()?.type == .comma {
                    _ = try consume(.comma)
                }
            }
            try consume(.rbracket)
            return .array(arr)
        case .lbrace:
            _ = try consume(.lbrace)
            var dict: [String: PropertyListValue] = [:]
            while let t = peek(), t.type != .rbrace {
                let k: String = if peek()?.type == .string {
                    try consume(.string).value
                } else if peek()?.type == .boolean {
                    try consume(.boolean).value
                } else {
                    try consume(.identifier).value
                }
                try consume(.colon)
                dict[k] = try parseValue()
                if peek()?.type == .comma {
                    _ = try consume(.comma)
                }
            }
            try consume(.rbrace)
            return .dictionary(dict)
        default:
            throw SyntaxError(line: tok.line, column: tok.column, kind: .unexpectedTokenInValue(found: tok.value))
        }
    }
}
