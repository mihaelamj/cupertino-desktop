@testable import Lexer
import Testing

@Suite("Localized diagnostics")
struct LocalizedDiagnosticTests {
    @Test("a diagnostic is typed data; prose is a per-locale rendering")
    func typedDiagnostic() {
        let error = SyntaxError(line: 1, column: 1, kind: .rootMustBeTemplate(found: "option"))
        #expect(error.code == "parse.root_must_be_template")
        #expect(error.arguments == ["option"])
        #expect(error.message == "root block must be 'template', found 'option'")
        #expect(error.localizedMessage(locale: "hr") == "korijenski blok mora biti 'template', pronađeno 'option'")
        // Untranslated diagnostics fall back to en, never to nothing.
        let other = SyntaxError(line: 1, column: 1, kind: .unterminatedString)
        #expect(other.localizedMessage(locale: "hr") == "unterminated string literal")
    }
}
