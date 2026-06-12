@testable import Documentation
import Testing

private let fixture = """
template "com.example.docs" {
    let Kind = "Xcode.IDEFoundation.TextSubstitutionFileTemplateKind"
    let Name = "Docs Fixture"
    option "languageChoice" {
        let Type = "popup"
        let Default = "Swift"
        unit "Swift" {
            node "___FILEBASENAME___.swift" {
                let content = "struct ___FILEBASENAMEASIDENTIFIER___ {}\\n// ___DATE___ by ___FULLUSERNAME___"
            }
        }
    }
}
"""

@Suite("Documentation catalog")
struct CatalogTests {
    @Test("every vocabulary table is non-empty and self-named")
    func tables() {
        #expect(Documentation.Catalog.keywords().count == 6)
        // FORMAT-REFERENCE counts 40 grouped keys; enumerated singly the table holds 41.
        #expect(Documentation.Catalog.manifestKeys().count >= 40)
        #expect(Documentation.Catalog.optionKeys().count >= 24)
        #expect(!Documentation.Catalog.definitionKeys().isEmpty)
        #expect(!Documentation.Catalog.optionTypeValues().isEmpty)
        #expect(Documentation.Catalog.macros().count > 100)
        for (name, entry) in Documentation.Catalog.macros() {
            #expect(entry.name == name)
            #expect(!entry.title.isEmpty)
            #expect(!entry.body.isEmpty)
        }
    }

    @Test("the en locale resource is complete: every key resolves with real text")
    func enTableComplete() {
        let table = Documentation.Strings.table(locale: "en")
        #expect(table.count > 200)
        var keys: [String] = []
        keys += Documentation.Catalog.keywordNames.map { "keyword." + $0 }
        keys += Documentation.Catalog.manifestKeyNames.map { "key.template." + $0 }
        keys += Documentation.Catalog.optionKeyNames.map { "key.option." + $0 }
        keys += Documentation.Catalog.definitionKeyNames.map { "key.definition." + $0 }
        keys += Documentation.Catalog.unitKeyNames.map { "key.unit." + $0 }
        keys += Documentation.Catalog.optionTypeValueNames.map { "type." + $0 }
        keys += (Documentation.Catalog.coreMacroNames + Documentation.Catalog.generatedContentMacroNames).map { "macro." + $0 }
        keys += Documentation.Catalog.modifierNames.map { "modifier." + $0 }
        let missing = keys.filter { table[$0] == nil || table[$0]!.title.isEmpty }
        #expect(missing.isEmpty, "missing en texts: \(missing)")
        // Display names are locale data, never Swift-derived English: every macro key must carry
        // an explicit display in the table.
        let macroKeysWithoutDisplay = table.keys.filter { $0.hasPrefix("macro.") && table[$0]?.display == nil }
        #expect(macroKeysWithoutDisplay.isEmpty, "macro keys missing display: \(macroKeysWithoutDisplay)")
    }

    @Test("a second language flows end to end; untranslated keys fall back to en per key")
    func croatianLocale() {
        // The catalog carries Croatian for two keys (the mechanism's proof): they render in hr.
        let entry = Documentation.Catalog.lookup(macro: "___PACKAGENAME___", locale: "hr")
        #expect(entry?.displayName == "Naziv proizvoda")
        // Untranslated parts of the same entry fall back to en, never to nothing.
        #expect(entry?.title.isEmpty == false)
        // Keys with no hr at all fall back to en wholesale.
        let fallback = Documentation.Catalog.lookup(macro: "___DATE___", locale: "hr")
        #expect(fallback?.displayName == "Today's Date")
        #expect(Documentation.Strings.availableLocales().contains("hr"))
    }

    @Test(
        "macro normalization folds families, modifiers, and spelling variants",
        arguments: [
            ("___VARIABLE_productName:identifier___", "___VARIABLE_*___"),
            ("___IMPORTHEADER_cocoaSubclass___", "___IMPORTHEADER_*___"),
            ("___ASSOCIATEDTARGET_bundleIdentifier___", "___ASSOCIATEDTARGET_*___"),
            ("___UUID:MAIN_GROUP___", "___UUID___"),
            ("___PACKAGENAME:identifier____", "___PACKAGENAME___"),
            ("____FILEBASENAMEASIDENTIFIER___", "___FILEBASENAMEASIDENTIFIER___"),
            ("___filebasename___", "___FILEBASENAME___"),
            ("___ProjectName___", "___PROJECTNAME___"),
            ("___DATE___", "___DATE___"),
        ],
    )
    func normalization(raw: String, expected: String) {
        #expect(Documentation.Catalog.normalize(macro: raw) == expected)
    }

    @Test("friendly display names replace hostile spellings (en locale table values)")
    func friendlyNames() {
        let macros = Documentation.Catalog.macros()
        #expect(macros["___PACKAGENAMEASIDENTIFIER___"]?.displayName == "Product Name (identifier-safe)")
        #expect(macros["___APP_ENTITY_DISPLAY_NAME___"]?.displayName == "App Entity Display Name")
        #expect(macros["___SWIFTDATA_CLASS_NAME___"]?.displayName == "SwiftData Class Name")
    }
}

@Suite("Annotator")
struct AnnotatorTests {
    @Test("annotates keywords, keys by context, type values, and macros")
    func annotateFixture() {
        let entries = Documentation.Annotator.annotate(source: fixture)
        let names = Set(entries.map(\.entry.name))
        #expect(names.contains("template"))
        #expect(names.contains("option"))
        #expect(names.contains("unit"))
        #expect(names.contains("node"))
        #expect(names.contains("Kind"))
        #expect(names.contains("Type"))
        #expect(names.contains("Default"))
        #expect(names.contains("content"))
        #expect(names.contains("popup"))
        #expect(names.contains("___FILEBASENAME___"))
        #expect(names.contains("___FILEBASENAMEASIDENTIFIER___"))
        #expect(names.contains("___DATE___"))
        #expect(names.contains("___FULLUSERNAME___"))
    }

    @Test("hover answers at a position with the innermost entry")
    func hover() {
        // Line 2: `    let Kind = ...`; column 9 is inside `Kind`.
        let hit = Documentation.Annotator.hover(source: fixture, line: 2, column: 9)
        #expect(hit?.entry.name == "Kind")
        #expect(hit?.entry.kind == .manifestKey)
    }

    @Test("macro scanning splits adjacent macros and rejects non-macros")
    func macroScan() {
        #expect(Documentation.Annotator.macros(in: "___A______B___") == ["___A___", "___B___"])
        #expect(Documentation.Annotator.macros(in: "___FILEBASENAME___.swift") == ["___FILEBASENAME___"])
        #expect(Documentation.Annotator.macros(in: "just ___ underscores here").isEmpty)
    }

    @Test("a broken source still annotates what survives")
    func brokenSource() {
        let entries = Documentation.Annotator.annotate(source: "template \"x\" { let Kind = \"k\" ; junk")
        #expect(entries.contains { $0.entry.name == "Kind" })
    }

    @Test("ranges are scanner-recorded, exact across escape sequences")
    func escapeExactRanges() {
        // `"a\nb"` is 6 source characters but 3 cooked; the entry range must cover the source.
        let source = "template \"x\" { let Name = \"a\\nb___DATE___\" }"
        let entries = Documentation.Annotator.annotate(source: source)
        let macroEntry = entries.first { $0.entry.name == "___DATE___" }
        #expect(macroEntry != nil)
        // The string lexeme starts at column 27; its source text is 2 delimiters + 14 source
        // characters (the escape is TWO source characters), so the range ends one past column 42.
        #expect(macroEntry?.startColumn == 27)
        #expect(macroEntry?.endColumn == 27 + 16)
    }
}

@Suite("Completer")
struct CompleterTests {
    @Test("after let, offers the enclosing construct's key vocabulary")
    func keysByContext() {
        // Cursor right after the `let` on line 2 (template body).
        let atTemplate = Documentation.Completer.complete(source: fixture, line: 2, column: 8)
        #expect(atTemplate.contains { $0.insertText == "Kind" })
        #expect(atTemplate.contains { $0.insertText == "Options" })
        // Cursor right after the `let` on line 5 (option body).
        let atOption = Documentation.Completer.complete(source: fixture, line: 5, column: 12)
        #expect(atOption.contains { $0.insertText == "Type" })
        #expect(atOption.contains { $0.insertText == "Units" })
        #expect(!atOption.contains { $0.insertText == "Ancestors" })
    }

    @Test("after let Type =, offers the widget vocabulary")
    func typeValues() {
        let items = Documentation.Completer.complete(source: fixture, line: 5, column: 18)
        #expect(items.contains { $0.insertText == "\"popup\"" })
        #expect(items.contains { $0.insertText == "\"checkbox\"" })
    }

    @Test("inside a string, offers macros labeled by friendly name")
    func macrosInString() {
        let items = Documentation.Completer.complete(source: fixture, line: 9, column: 40)
        let fileBase = items.first { $0.insertText == "___FILEBASENAME___" }
        #expect(fileBase != nil)
        #expect(fileBase?.label == "File Name (no extension)")
    }

    @Test("at item position, offers exactly the constructs legal in that body")
    func itemKeywords() {
        // Line 4 column 5: item position inside the template body.
        let atTemplate = Documentation.Completer.complete(source: fixture, line: 4, column: 4)
        let labels = Set(atTemplate.map(\.insertText))
        #expect(labels.contains("option"))
        #expect(labels.contains("node"))
        #expect(!labels.contains("unit"))
    }

    @Test("empty source offers template")
    func emptySource() {
        let items = Documentation.Completer.complete(source: "", line: 1, column: 1)
        #expect(items.map(\.insertText) == ["template"])
    }
}
