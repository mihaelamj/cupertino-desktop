@testable import Documentation
import Testing

/// Display-only shortening: macros and kind identifiers render friendly, the original
/// text stays the truth, nil means nothing changed.
@Suite("Display shortening")
struct DisplayShorteningTests {
    @Test("a bare macro renders its catalog display name")
    func bareMacro() {
        #expect(Documentation.Catalog.display(for: "___FILEBASENAME___.swift") == "File Name (no extension).swift")
    }

    @Test("a modifier tail composes as a parenthesized suffix")
    func modifierComposition() throws {
        let shortened = Documentation.Catalog.display(for: "___PACKAGENAME:identifier___")
        #expect(shortened != nil)
        #expect(try #require(shortened?.contains("Product Name")), "the catalog displays PACKAGENAME as Product Name")
        #expect(try #require(shortened?.contains("(")))
        #expect(try !(#require(shortened?.contains("___"))))
    }

    @Test("kind identifiers render their short names")
    func kindNames() {
        let shortened = Documentation.Catalog.display(for: "Xcode.IDEFoundation.TextSubstitutionFileTemplateKind")
        #expect(shortened == "File Template")
        #expect(Documentation.Catalog.display(for: "Xcode.Xcode3.ProjectTemplateUnitKind") == "Project Template Unit")
    }

    @Test("mixed text shortens every species; plain text returns nil")
    func mixedAndPlain() {
        let mixed = Documentation.Catalog.display(
            for: "node \"___FILEBASENAME___.swift\" of Xcode.IDEFoundation.TextSubstitutionFileTemplateKind",
        )
        #expect(mixed == "node \"File Name (no extension).swift\" of File Template")
        #expect(Documentation.Catalog.display(for: "no macros here") == nil)
    }

    @Test("every kind identifier has its catalog name")
    func allKindsNamed() {
        for identifier in Documentation.Catalog.kindIdentifierNames {
            let shortened = Documentation.Catalog.display(for: identifier)
            #expect(shortened != nil && shortened!.contains("Xcode.") == false, Comment(rawValue: identifier))
        }
    }
}
