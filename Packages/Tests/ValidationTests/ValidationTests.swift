import SharedModels
import Testing
@testable import Validation

@Suite("Validation Tests")
struct ValidationTests {
    @Test("Verifies that validator successfully passes a valid bundle")
    func validBundle() throws {
        let bundle = XcodeTemplateBundle(
            name: "MyTemplate",
            identifier: "com.example.test",
            metadata: [
                "Kind": .string("Xcode.Xcode3.ProjectTemplateUnitKind"),
                "Ancestors": .array([.string("com.example.parent")]),
                "Options": .array([
                    .dictionary([
                        "Identifier": .string("myOption"),
                        "Type": .string("popup"),
                    ]),
                ]),
            ],
            files: ["main.swift": FileInfo(type: "text", content: "print(1)")],
        )

        let validator = Validator<XcodeTemplateBundle>.defaultTemplateValidator
        #expect(throws: Never.self) {
            try validator.validate(bundle)
        }
    }

    @Test("Verifies that validator catches an empty template identifier")
    func emptyIdentifier() throws {
        let bundle = XcodeTemplateBundle(
            name: "MyTemplate",
            identifier: "",
            metadata: ["Kind": .string("Xcode.Xcode3.ProjectTemplateUnitKind")],
            files: ["main.swift": FileInfo(type: "text", content: "print(1)")],
        )

        let validator = Validator<XcodeTemplateBundle>.defaultTemplateValidator

        #expect(throws: ValidationErrorCollection.self) {
            try validator.validate(bundle)
        }

        do {
            try validator.validate(bundle)
        } catch let errors as ValidationErrorCollection {
            #expect(errors.values.count == 1)
            #expect(errors.values[0].description == "Failed to satisfy: Project template identifier is not empty at root of document")
        }
    }

    @Test("Verifies that validator catches an empty or non-string kind")
    func invalidKind() throws {
        // Kind is an open vocabulary, so any non-empty string is valid; only an empty (or non-string)
        // Kind is malformed.
        let bundle = XcodeTemplateBundle(
            name: "MyTemplate",
            identifier: "com.example.test",
            metadata: ["Kind": .string("")],
            files: ["main.swift": FileInfo(type: "text", content: "print(1)")],
        )

        let validator = Validator<XcodeTemplateBundle>.defaultTemplateValidator

        #expect(throws: ValidationErrorCollection.self) {
            try validator.validate(bundle)
        }

        do {
            try validator.validate(bundle)
        } catch let errors as ValidationErrorCollection {
            #expect(errors.values.count == 1)
            #expect(errors.values[0].description == "Failed to satisfy: Template Kind is valid at root of document")
        }
    }

    @Test("Verifies that validator catches non-string ancestors")
    func invalidAncestors() throws {
        let bundle = XcodeTemplateBundle(
            name: "MyTemplate",
            identifier: "com.example.test",
            metadata: [
                "Kind": .string("Xcode.Xcode3.ProjectTemplateUnitKind"),
                "Ancestors": .array([.integer(123)]),
            ],
            files: ["main.swift": FileInfo(type: "text", content: "print(1)")],
        )

        let validator = Validator<XcodeTemplateBundle>.defaultTemplateValidator

        #expect(throws: ValidationErrorCollection.self) {
            try validator.validate(bundle)
        }

        do {
            try validator.validate(bundle)
        } catch let errors as ValidationErrorCollection {
            #expect(errors.values.count == 1)
            #expect(errors.values[0].description == "Failed to satisfy: Template Ancestors is an array of strings at root of document")
        }
    }

    @Test("Verifies that validator catches invalid options")
    func invalidOptions() throws {
        let bundle = XcodeTemplateBundle(
            name: "MyTemplate",
            identifier: "com.example.test",
            metadata: [
                "Kind": .string("Xcode.Xcode3.ProjectTemplateUnitKind"),
                "Options": .array([
                    .dictionary([
                        "Identifier": .string(""),
                        "Type": .string("popup"),
                    ]),
                ]),
            ],
            files: ["main.swift": FileInfo(type: "text", content: "print(1)")],
        )

        let validator = Validator<XcodeTemplateBundle>.defaultTemplateValidator

        #expect(throws: ValidationErrorCollection.self) {
            try validator.validate(bundle)
        }

        do {
            try validator.validate(bundle)
        } catch let errors as ValidationErrorCollection {
            #expect(errors.values.count == 1)
            #expect(errors.values[0].description == "Failed to satisfy: Template Options are valid at root of document")
        }
    }

    @Test("Verifies that empty file content is allowed")
    func emptyFileContentAllowed() throws {
        // An empty file is valid (an "Empty File" template, a .gitkeep, an empty stub), so the default
        // validator must accept it.
        let bundle = XcodeTemplateBundle(
            name: "MyTemplate",
            identifier: "com.example.test",
            metadata: ["Kind": .string("Xcode.Xcode3.ProjectTemplateUnitKind")],
            files: ["___FILENAME___": FileInfo(type: "text", content: "")],
        )

        let validator = Validator<XcodeTemplateBundle>.defaultTemplateValidator

        #expect(throws: Never.self) {
            try validator.validate(bundle)
        }
    }

    @Test("Verifies that a file template with no identifier is allowed")
    func fileTemplateNoIdentifierAllowed() throws {
        // File, playground, and test-plan templates legitimately have no Identifier and are keyed on Kind.
        let bundle = XcodeTemplateBundle(
            name: "MyTemplate",
            identifier: "",
            metadata: ["Kind": .string("Xcode.IDEFoundation.TextSubstitutionFileTemplateKind")],
            files: ["___FILEBASENAME___.swift": FileInfo(type: "text", content: "import Foundation\n")],
        )

        let validator = Validator<XcodeTemplateBundle>.defaultTemplateValidator

        #expect(throws: Never.self) {
            try validator.validate(bundle)
        }
    }

    @Test("Verifies that an option with no Type is allowed")
    func optionWithoutTypeAllowed() throws {
        // An absent option Type means the default kind, which is valid and common.
        let bundle = XcodeTemplateBundle(
            name: "MyTemplate",
            identifier: "com.example.test",
            metadata: [
                "Kind": .string("Xcode.Xcode3.ProjectTemplateUnitKind"),
                "Options": .array([.dictionary(["Identifier": .string("productName")])]),
            ],
            files: ["main.swift": FileInfo(type: "text", content: "print(1)")],
        )

        let validator = Validator<XcodeTemplateBundle>.defaultTemplateValidator

        #expect(throws: Never.self) {
            try validator.validate(bundle)
        }
    }

    @Test("Diagnostic flags a case-inconsistent path (output key vs source Path)")
    func caseInconsistentPathFlagged() throws {
        // The Definition output key and its source Path differ only by letter case: portable on macOS,
        // broken on a case-sensitive filesystem.
        let bundle = XcodeTemplateBundle(
            name: "MyTemplate",
            identifier: "com.example.test",
            metadata: [
                "Kind": .string("Xcode.Xcode3.ProjectTemplateUnitKind"),
                "Definitions": .dictionary([
                    "Base.lproj/Main.xib": .dictionary(["Path": .string("base.lproj/Main.xib")]),
                ]),
            ],
            files: ["base.lproj/Main.xib": FileInfo(type: "text", content: "<xib/>")],
        )

        #expect(bundle.pathCaseCollisions.count == 1)
        let validator = Validator<XcodeTemplateBundle>.diagnosticValidator
        #expect(throws: ValidationErrorCollection.self) {
            try validator.validate(bundle)
        }
    }

    @Test("Diagnostic passes a case-consistent template")
    func caseConsistentPathPasses() throws {
        let bundle = XcodeTemplateBundle(
            name: "MyTemplate",
            identifier: "com.example.test",
            metadata: [
                "Kind": .string("Xcode.Xcode3.ProjectTemplateUnitKind"),
                "Definitions": .dictionary([
                    "Base.lproj/Main.xib": .dictionary(["Path": .string("Base.lproj/Main.xib")]),
                ]),
            ],
            files: ["Base.lproj/Main.xib": FileInfo(type: "text", content: "<xib/>")],
        )

        #expect(bundle.pathCaseCollisions.isEmpty)
        let validator = Validator<XcodeTemplateBundle>.diagnosticValidator
        #expect(throws: Never.self) {
            try validator.validate(bundle)
        }
    }

    @Test("Diagnostic flags an incomplete option (unselectable default, mismatched value titles)")
    func incompleteOptionFlagged() throws {
        let bundle = XcodeTemplateBundle(
            name: "MyTemplate",
            identifier: "com.example.test",
            metadata: [
                "Kind": .string("Xcode.Xcode3.ProjectTemplateUnitKind"),
                "Options": .array([.dictionary([
                    "Identifier": .string("ui"),
                    "Type": .string("popup"),
                    "Values": .array([.string("SwiftUI"), .string("UIKit")]),
                    "Default": .string("Storyboard"),
                    "ValueTitles": .array([.string("Only One")]),
                ])]),
            ],
            files: [:],
        )
        #expect(bundle.optionCompletenessIssues.count == 2)
        let validator = Validator<XcodeTemplateBundle>.diagnosticValidator
        #expect(throws: ValidationErrorCollection.self) {
            try validator.validate(bundle)
        }
    }

    @Test("Diagnostic passes a complete option (selectable default, matched value titles)")
    func completeOptionPasses() throws {
        let bundle = XcodeTemplateBundle(
            name: "MyTemplate",
            identifier: "com.example.test",
            metadata: [
                "Kind": .string("Xcode.Xcode3.ProjectTemplateUnitKind"),
                "Options": .array([.dictionary([
                    "Identifier": .string("ui"),
                    "Type": .string("popup"),
                    "Values": .array([.string("SwiftUI"), .string("UIKit")]),
                    "Default": .string("SwiftUI"),
                    "ValueTitles": .array([.string("SwiftUI"), .string("UIKit")]),
                ])]),
            ],
            files: [:],
        )
        #expect(bundle.optionCompletenessIssues.isEmpty)
        let validator = Validator<XcodeTemplateBundle>.diagnosticValidator
        #expect(throws: Never.self) {
            try validator.validate(bundle)
        }
    }

    @Test("Diagnostic flags dangling references (node, definition path, content macro)")
    func danglingReferencesFlagged() throws {
        let bundle = XcodeTemplateBundle(
            name: "MyTemplate",
            identifier: "com.example.test",
            metadata: [
                "Kind": .string("Xcode.Xcode3.ProjectTemplateUnitKind"),
                "Nodes": .array([.string("Ghost.swift")]),
                "Definitions": .dictionary([
                    "Missing.swift": .dictionary(["Path": .string("nowhere/Missing.swift")]),
                ]),
            ],
            files: ["main.swift": FileInfo(type: "text", content: "let x = \"___VARIABLE_undeclaredThing___\"")],
        )
        let issues = bundle.referentialIntegrityIssues
        #expect(issues.count == 3)
        #expect(issues.contains { $0.contains("Ghost.swift") })
        #expect(issues.contains { $0.contains("nowhere/Missing.swift") })
        #expect(issues.contains { $0.contains("undeclaredThing") })
        let validator = Validator<XcodeTemplateBundle>.diagnosticValidator
        #expect(throws: ValidationErrorCollection.self) {
            try validator.validate(bundle)
        }
    }

    @Test("Diagnostic passes resolved references, implicit variables, and ancestored templates")
    func resolvedReferencesPass() {
        // A node backed by a Definition whose Path is a physical file, a macro naming a declared option,
        // and a macro naming an implicit variable (productName) all resolve.
        let clean = XcodeTemplateBundle(
            name: "MyTemplate",
            identifier: "com.example.test",
            metadata: [
                "Kind": .string("Xcode.Xcode3.ProjectTemplateUnitKind"),
                "Nodes": .array([.string("App.swift")]),
                "Options": .array([.dictionary(["Identifier": .string("appType"), "Type": .string("text")])]),
                "Definitions": .dictionary([
                    "App.swift": .dictionary(["Path": .string("src/App.swift")]),
                ]),
            ],
            files: ["src/App.swift": FileInfo(type: "text", content: "// ___VARIABLE_appType___ ___VARIABLE_productName___")],
        )
        #expect(clean.referentialIntegrityIssues.isEmpty)

        // A template with Ancestors is skipped entirely: its references resolve through the lineage.
        let ancestored = XcodeTemplateBundle(
            name: "Child",
            identifier: "com.example.child",
            metadata: [
                "Kind": .string("Xcode.Xcode3.ProjectTemplateUnitKind"),
                "Ancestors": .array([.string("com.example.parent")]),
                "Nodes": .array([.string("InheritedFile.swift")]),
            ],
            files: [:],
        )
        #expect(ancestored.referentialIntegrityIssues.isEmpty)
    }
}
