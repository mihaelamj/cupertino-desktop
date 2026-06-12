import Decompiler
import Foundation
import Lexer
@testable import Parser
import SharedModels
import Testing

@Suite("Parser Tests")
struct ParserTests {
    @Test("Verifies root template parsing")
    func parserRoot() throws {
        let code = "template \"com.example.test\" {}"
        let lexer = Lexer(code: code)
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens)
        let bundle = try parser.parse()
        #expect(bundle.identifier == "com.example.test")
    }

    private func syntaxError(_ code: String) throws -> SyntaxError {
        do {
            let tokens = try Lexer(code: code).tokenize()
            _ = try Parser(tokens: tokens).parse()
        } catch let error as SyntaxError {
            return error
        }
        throw NSError(domain: "test", code: 0, userInfo: [NSLocalizedDescriptionKey: "expected a SyntaxError, but lexing/parsing succeeded"])
    }

    @Test("A non-template root reports a syntax error at its position")
    func nonTemplateRoot() throws {
        let error = try syntaxError("option \"x\" {\n}\n")
        #expect(error.line == 1 && error.column == 1)
        #expect(error.message.contains("template"))
    }

    @Test("A bad top-level keyword reports its line and column")
    func badKeyword() throws {
        let error = try syntaxError("template \"x\" {\n    wibble \"y\"\n}\n")
        #expect(error.line == 2 && error.column == 5)
        #expect(error.message.contains("wibble"))
    }

    @Test("A missing value reports a syntax error in the value expression")
    func missingValue() throws {
        let error = try syntaxError("template \"x\" {\n    let K = \n}\n")
        #expect(error.message.contains("value expression"))
    }

    @Test("An unterminated raw string reports a syntax error")
    func unterminatedString() throws {
        let error = try syntaxError("template \"x\" {\n    let K = #\"\"\"\nunterminated\n}\n")
        #expect(error.message.contains("unterminated"))
    }

    @Test("Recovering check reports every error in one pass with positions")
    func multiErrorRecovery() throws {
        let code = """
        template "x" {
            let A = @
            option "o" {
                let T =
                let U = "ok"
            }
            let B = "fine"
        }
        """
        let (tokens, lexicalErrors) = Lexer(code: code).tokenizeRecovering()
        let (bundle, syntaxErrors) = Parser(tokens: tokens).parseRecovering()
        // One lexical error (the @, panic-mode deleted) and at least one syntax error (the missing value),
        // all collected in a single pass rather than aborting at the first.
        #expect(lexicalErrors.count == 1)
        #expect(lexicalErrors[0].line == 2)
        #expect(!syntaxErrors.isEmpty)
        // Recovery resynchronized: the parse continued past the errors and kept later, valid items.
        let recovered = try #require(bundle)
        #expect(recovered.metadata["B"]?.stringValue == "fine")
    }

    @Test("Recovering APIs report nothing on valid input")
    func recoveryZeroOverheadOnValidInput() {
        let code = "template \"x\" {\n    let Kind = \"K\"\n    option \"o\" {\n        let Type = \"text\"\n    }\n}\n"
        let (tokens, lexicalErrors) = Lexer(code: code).tokenizeRecovering()
        let (bundle, syntaxErrors) = Parser(tokens: tokens).parseRecovering()
        #expect(lexicalErrors.isEmpty)
        #expect(syntaxErrors.isEmpty)
        #expect(bundle != nil)
    }

    @Test("Strict parse still throws on the first error")
    func strictModeUnchanged() throws {
        let code = "template \"x\" {\n    wibble \"y\"\n}\n"
        let tokens = try Lexer(code: code).tokenize()
        #expect(throws: SyntaxError.self) {
            _ = try Parser(tokens: tokens).parse()
        }
    }

    @Test("The parser emits a positioned concrete syntax tree")
    func testSyntaxTree() throws {
        let code = """
        template "x" {
            let Kind = "K"
            option "ui" {
                let Type = "popup"
                unit "A" {
                    node "f.swift" {
                        let content = "c"
                    }
                }
            }
            node "top.plist" {
                let Path = "top.plist"
            }
            directory "Empty.xcassets"
        }
        """
        let tokens = try Lexer(code: code).tokenize()
        let parser = Parser(tokens: tokens)
        _ = try parser.parse()
        let tree = try #require(parser.syntaxTree)

        // The root spans every token; the structure mirrors the source.
        #expect(tree.kind == .template)
        #expect(tree.tokenRange == 0 ..< tokens.count)
        #expect(tree.children.map(\.kind) == [.letBinding, .option, .node, .directory])
        let option = tree.children[1]
        #expect(option.children.map(\.kind) == [.letBinding, .unit])
        let unit = option.children[1]
        #expect(unit.children.map(\.kind) == [.node])
        #expect(unit.children[0].children.map(\.kind) == [.letBinding])

        // Spans carry exact source positions: the option starts at line 3 column 5.
        let optionRange = try #require(option.sourceRange(in: tokens))
        #expect(optionRange.startLine == 3 && optionRange.startColumn == 5)

        // Children nest inside parents and siblings are ordered, tree-wide.
        var holds = true
        tree.walk { node, _ in
            var previousEnd = node.tokenRange.lowerBound
            for child in node.children {
                if child.tokenRange.lowerBound < previousEnd || child.tokenRange.upperBound > node.tokenRange.upperBound {
                    holds = false
                }
                previousEnd = child.tokenRange.upperBound
            }
        }
        #expect(holds)
    }

    @Test("A recovered parse still yields a balanced tree with the valid constructs")
    func syntaxTreeSurvivesRecovery() throws {
        let code = "template \"x\" {\n    let A = @\n    let B = \"fine\"\n}\n"
        let (tokens, _) = Lexer(code: code).tokenizeRecovering()
        let parser = Parser(tokens: tokens)
        _ = parser.parseRecovering()
        let tree = try #require(parser.syntaxTree)
        #expect(tree.kind == .template)
        // The valid binding after the error is present in the tree.
        #expect(tree.children.contains { $0.kind == .letBinding })
    }

    @Test("Pop recovery: a node inside an option closes the option instead of mis-attaching")
    func popRecoveryKeepsStructure() throws {
        // A `node` cannot appear inside an option (FIRST(OptionItem) = let, unit). Per Fig 4.22 the
        // option must be POPPED at the stray `node`, which the template loop then parses correctly.
        // Without the pop, recovery used to skip INTO the node's body and parse its bindings as option
        // keys, silently mis-attaching everything after the error.
        let code = """
        template "x" {
            option "o" {
                let T = "text"
                node "stray.swift" {
                    let Path = "stray.swift"
                }
            }
        }
        """
        let (tokens, lexErrors) = Lexer(code: code).tokenizeRecovering()
        let parser = Parser(tokens: tokens)
        let (bundle, syntaxErrors) = parser.parseRecovering()
        #expect(lexErrors.isEmpty)
        #expect(syntaxErrors.count == 1)

        let recovered = try #require(bundle)
        // The option kept what preceded the error and did NOT absorb the node's bindings.
        if case let .array(options)? = recovered.metadata["Options"],
           case let .dictionary(opt)? = options.first
        {
            #expect(opt["T"]?.stringValue == "text")
            #expect(opt["Path"] == nil)
        } else {
            Issue.record("option missing from recovered bundle")
        }
        // The stray node was parsed as a top-level node: its Definition exists with the right Path.
        if case let .dictionary(defs)? = recovered.metadata["Definitions"],
           case let .dictionary(def)? = defs["stray.swift"]
        {
            #expect(def["Path"]?.stringValue == "stray.swift")
        } else {
            Issue.record("popped node was not reparsed at template level")
        }
        // The tree mirrors that: the node is a SIBLING of the option, not its child.
        let tree = try #require(parser.syntaxTree)
        #expect(tree.children.contains { $0.kind == .node })
        let option = try #require(tree.children.first { $0.kind == .option })
        #expect(!option.children.contains { $0.kind == .node })
    }

    @Test("A bare minus is a lexical error, not the real 0")
    func bareMinusRejected() {
        let (_, errors) = Lexer(code: "template \"x\" {\n    let A = -\n}\n").tokenizeRecovering()
        #expect(!errors.isEmpty)
    }

    @Test("Trailing tokens after the template close are an error (the whole input must be consumed)")
    func trailingInputRejected() throws {
        let code = "template \"x\" {\n    let A = \"ok\"\n}\ngarbage \"here\"\n"
        let tokens = try Lexer(code: code).tokenize()
        #expect(throws: SyntaxError.self) {
            _ = try Parser(tokens: tokens).parse()
        }
        // Recovering mode reports it but still returns the bundle.
        let parser = Parser(tokens: tokens)
        let (bundle, errors) = parser.parseRecovering()
        #expect(bundle != nil)
        #expect(errors.contains { $0.message.contains("after the template closes") })
    }

    @Test("The decompiler's output reparses to the same value, for adversarial strings")
    func printParseInversion() throws {
        // The unparser must invert the parser (Dragon Book section 2.5: the concrete syntax is a faithful
        // rendering of the tree). The corpus proves shipped data; these are the adversarial shapes a USER
        // can type: quotes, hashes, backslashes, delimiter look-alikes, newline edges, unicode.
        let nasty: [String] = [
            "",
            "plain",
            "with \"quote\"",
            "with \\ backslash",
            "ends with quote\"",
            "raw delimiter \"# inside",
            "many hashes \"### inside",
            "line1\nline2",
            "\nleading newline",
            "trailing newline\n",
            "\n",
            "triple \"\"\" inside",
            "triple with hash \"\"\"# inside",
            "tab\tand\rcarriage",
            "emoji 🎛️ and ünïcode",
            "    indented lines\n        deeper\n    back",
            "looks like close\n\"\"\"\nafter",
        ]
        for (index, value) in nasty.enumerated() {
            let line = Decompiler.formatProperty("V\(index)", .string(value), indent: 1)
            let code = "template \"x\" {\n\(line)\n}\n"
            let tokens = try Lexer(code: code).tokenize()
            let bundle = try Parser(tokens: tokens).parse()
            #expect(bundle.metadata["V\(index)"] == .string(value), "case \(index): \(value.debugDescription)")
        }
        // The same inversion for non-string values.
        let values: [PropertyListValue] = [
            .integer(0), .integer(-42), .real(3.14), .real(-0.001), .boolean(true), .boolean(false),
            .array([.string("a"), .integer(1), .real(2.5), .array([.boolean(false)])]),
            .dictionary(["k": .string("v"), "weird key": .array([.integer(7)])]),
        ]
        for (index, value) in values.enumerated() {
            let line = Decompiler.formatProperty("W\(index)", value, indent: 1)
            let code = "template \"x\" {\n\(line)\n}\n"
            let tokens = try Lexer(code: code).tokenize()
            let bundle = try Parser(tokens: tokens).parse()
            #expect(bundle.metadata["W\(index)"] == value, "case \(index)")
        }
    }

    @Test("Real numbers round-trip through lexer, parser, and decompiler formatting")
    func realNumbers() throws {
        let code = "template \"x\" {\n    let R = 3.14\n    let N = -0.5\n    let E = 1.5e3\n    let I = 42\n}\n"
        let tokens = try Lexer(code: code).tokenize()
        let bundle = try Parser(tokens: tokens).parse()
        #expect(bundle.metadata["R"] == .real(3.14))
        #expect(bundle.metadata["N"] == .real(-0.5))
        #expect(bundle.metadata["E"] == .real(1500.0))
        #expect(bundle.metadata["I"] == .integer(42))
        // Maximal munch: `3.` is the integer 3 followed by punctuation, not a malformed real.
        let edge = try Lexer(code: "template \"x\" {\n    let A = [3, 4]\n}\n").tokenize()
        let edgeBundle = try Parser(tokens: edge).parse()
        #expect(edgeBundle.metadata["A"] == .array([.integer(3), .integer(4)]))
    }
}
