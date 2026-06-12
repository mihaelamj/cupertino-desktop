@testable import Lexer
import Testing

@Suite("Lexer Tests")
struct LexerTests {
    @Test("Verifies simple tokenization")
    func tokenization() throws {
        let lexer = Lexer(code: "let x = 123")
        let tokens = try lexer.tokenize()
        #expect(tokens.count == 4)
        #expect(tokens[0].type == .letKeyword)
        #expect(tokens[1].type == .identifier)
        #expect(tokens[2].type == .equals)
        #expect(tokens[3].type == .number)
    }

    /// Maximal munch is a rollback protocol (Cooper and Torczon, section 2.5, Figure 2.15): when the
    /// recognizer overshoots past its last accepting state, EVERY overshot character must be given
    /// back. The exponent branch implements this as lookahead-before-commit, so a failed exponent
    /// tail surrenders the `e` AND the sign together, never just the trailing character.
    @Test(
        "A failed exponent tail rolls back the e and the sign together",
        arguments: [
            ("let x = 12e+", "12", 1), // e and + both surrendered; + is the lexical error
            ("let x = 12e-", "12", 1), // e surrendered; - with no digit is the lexical error
            ("let x = 12E+y", "12", 1), // E and + surrendered; + errors, y lexes as identifier
            ("let x = 3.5e", "3.5", 0), // bare e surrendered; lexes as the identifier e
        ],
    )
    func exponentRollback(source: String, number: String, lexicalErrors: Int) {
        let (tokens, errors) = Lexer(code: source).tokenizeRecovering()
        let numberToken = tokens.first { $0.type == .number }
        #expect(numberToken?.value == number)
        #expect(errors.count == lexicalErrors)
    }

    @Test("A hash that never opens a raw string is one deleted character, not an absorbed prefix")
    func bareHashRollback() {
        let (tokens, errors) = Lexer(code: "let x = #5").tokenizeRecovering()
        #expect(errors.count == 1)
        #expect(errors[0].message.contains("#"))
        // The 5 after the deleted # must still arrive as a number: recovery deletes exactly one character.
        #expect(tokens.contains { $0.type == .number && $0.value == "5" })
    }

    @Test("Consecutive stray hashes produce one error each, single-edit repair per error")
    func doubleHashRollback() {
        let (tokens, errors) = Lexer(code: "let x = ##7").tokenizeRecovering()
        #expect(errors.count == 2)
        #expect(tokens.contains { $0.type == .number && $0.value == "7" })
    }
}
