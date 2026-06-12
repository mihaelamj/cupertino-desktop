@testable import Documentation
import Testing

/// Macro annotations hug their spellings where exactness is provable: an escape-free
/// cooked prefix means raw and cooked offsets agree; behind an escape the entry keeps
/// the documented whole-string span.
@Suite("Macro sub-ranges")
struct MacroSubRangeTests {
    private func macroAnnotations(_ source: String) -> [Documentation.PositionedEntry] {
        Documentation.Annotator.annotate(source: source).filter { $0.entry.kind == .macro }
    }

    @Test("an escape-free prefix yields the exact spelling range")
    func exactRange() {
        let source = "node \"___FILEBASENAME___.swift\" {"
        let annotations = macroAnnotations(source)
        #expect(annotations.count == 1)
        // node "___FILEBASENAME___.swift": the spelling starts at column 7 (after `node "`).
        #expect(annotations[0].startColumn == 7)
        #expect(annotations[0].endColumn == 7 + "___FILEBASENAME___".count)
        #expect(annotations[0].startLine == 1 && annotations[0].endLine == 1)
    }

    @Test("a macro before the escape is exact; the whole-string fallback survives behind one")
    func mixedEscapes() {
        let before = "let content = \"struct ___FILEBASENAMEASIDENTIFIER___ {}\\n\""
        let annotations = macroAnnotations(before)
        #expect(annotations.count == 1)
        #expect(annotations[0].endColumn - annotations[0].startColumn == "___FILEBASENAMEASIDENTIFIER___".count)

        let after = "let content = \"a\\n___DATE___\""
        let fallback = macroAnnotations(after)
        #expect(fallback.count == 1)
        // Behind the escape the offsets shift, so the entry spans the whole string token.
        #expect(fallback[0].endColumn - fallback[0].startColumn > "___DATE___".count)
    }
}
