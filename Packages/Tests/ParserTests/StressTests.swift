import Foundation
import Lexer
@testable import Parser
import Testing

/// Findings from the IDE stress-test coverage, pinned so they stay fixed.
@Suite("Editor stress findings")
struct StressTests {
    @Test("deep value nesting is a positioned diagnostic, never a stack overflow")
    func deepNesting() {
        let source = "template \"deep\" {\n    let K = " + String(repeating: "[", count: 20000) + String(repeating: "]", count: 20000) + "\n}"
        let (tokens, _) = Lexer(code: source).tokenizeRecovering()
        let (_, errors) = Parser(tokens: tokens).parseRecovering()
        #expect(errors.contains { $0.code == "parse.nesting_too_deep" })
    }

    @Test("nesting within the bound still parses")
    func nestingWithinBound() throws {
        let source = "template \"ok\" {\n    let K = " + String(repeating: "[", count: 32) + String(repeating: "]", count: 32) + "\n}"
        let tokens = try Lexer(code: source).tokenize()
        let bundle = try Parser(tokens: tokens).parse()
        #expect(bundle.identifier == "ok")
    }

    @Test("the root spans the whole buffer even when the parse aborts mid-token")
    func rootSpansBufferAfterAbort() {
        // Doubly-unterminated source: the throw used to leave the offending token outside the root.
        let source = "template \"unterminated {\n    let Kind = \"k\n"
        let (tokens, _) = Lexer(code: source).tokenizeRecovering()
        let parser = Parser(tokens: tokens)
        _ = parser.parseRecovering()
        let tree = parser.syntaxTree
        #expect(tree != nil)
        #expect(tree?.tokenRange == 0 ..< tokens.count)
    }
}

/// The IDE drives analysis on EVERY keystroke: every prefix of a source must answer without
/// crashing, and recovery must keep the editor services (outline, hover vocabulary) alive.
@Suite("Keystroke coverage")
struct KeystrokeCoverageTests {
    @Test("every prefix of a real template parses recoveringly without crashing")
    func everyPrefix() {
        let source = """
        template "com.example.keystrokes" {
            let Kind = "Xcode.IDEFoundation.TextSubstitutionFileTemplateKind"
            let Name = "Keystroke Fixture"
            option "languageChoice" {
                let Type = "popup"
                let Default = "Swift"
                let Values = ["Swift", "Objective-C"]
                unit "Swift" {
                    node "___FILEBASENAME___.swift" {
                        let binary = false
                        let content = "struct ___FILEBASENAMEASIDENTIFIER___ {}\\n"
                    }
                }
            }
            directory "Empty"
        }
        """
        var treesSeen = 0
        for end in source.indices {
            let prefix = String(source[..<end])
            let (tokens, _) = Lexer(code: prefix).tokenizeRecovering()
            let parser = Parser(tokens: tokens)
            _ = parser.parseRecovering()
            if let tree = parser.syntaxTree {
                treesSeen += 1
                // The hardened invariant: whatever survived, the root spans every token.
                #expect(tree.tokenRange == 0 ..< tokens.count)
            }
        }
        // Recovery keeps the tree alive for the overwhelming majority of keystrokes.
        #expect(treesSeen > source.count / 2)
    }

    @Test("analysis is safe to run concurrently from many worker threads")
    func concurrentAnalysis() async {
        let source = "template \"con\" {\n    let Kind = \"k\"\n    option \"o\" { let Type = \"popup\" }\n}"
        await withTaskGroup(of: Int.self) { group in
            for _ in 0 ..< 16 {
                group.addTask {
                    var total = 0
                    for _ in 0 ..< 50 {
                        let (tokens, lexErrors) = Lexer(code: source).tokenizeRecovering()
                        let (bundle, parseErrors) = Parser(tokens: tokens).parseRecovering()
                        total += tokens.count + lexErrors.count + parseErrors.count + (bundle == nil ? 1 : 0)
                    }
                    return total
                }
            }
            var results: Set<Int> = []
            for await value in group {
                results.insert(value)
            }
            // Every thread computed the identical answer: no shared-state corruption.
            #expect(results.count == 1)
        }
    }
}
