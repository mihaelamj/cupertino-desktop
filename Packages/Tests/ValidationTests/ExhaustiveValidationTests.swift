import Foundation
import SharedModels
import Testing
@testable import Validation

/// Every rule, both directions, exhaustively: for each code in the registries a fixture
/// that trips exactly that rule and a near-miss fixture at the boundary the rule almost
/// trips; the configuration-pin test over exact validator descriptions; the machinery's
/// own negative tests; a many-error bundle asserting its complete list; and the meta-test
/// that names any rule shipped without its fixtures.
@Suite("Exhaustive validation coverage")
struct ExhaustiveValidationTests {
    static func bundle(
        identifier: String = "com.example.test",
        metadata: [String: PropertyListValue] = [:],
        files: [String: FileInfo] = ["main.swift": FileInfo(type: "text", content: "print(1)")],
    ) -> XcodeTemplateBundle {
        var metadata = metadata
        if metadata["Kind"] == nil {
            metadata["Kind"] = .string("Xcode.Xcode3.ProjectTemplateUnitKind")
        }
        return XcodeTemplateBundle(name: "Test", identifier: identifier, metadata: metadata, files: files)
    }

    // MARK: Default-gate rules, failing and near-miss fixtures

    static let defaultRuleCases: [(code: String, failing: XcodeTemplateBundle, nearMiss: XcodeTemplateBundle)] = [
        (
            "rule.identifier_not_empty",
            bundle(identifier: ""),
            // The boundary: an empty identifier is valid for every non-project kind.
            bundle(identifier: "", metadata: ["Kind": .string("Xcode.IDEFoundation.TextBasedFileTemplateKind")])
        ),
        (
            "rule.kind_valid",
            bundle(metadata: ["Kind": .boolean(true)]),
            // The boundary: an absent Kind is a valid base/partial template.
            XcodeTemplateBundle(name: "Test", identifier: "com.example.test", metadata: [:], files: ["main.swift": FileInfo(type: "text", content: "print(1)")])
        ),
        (
            "rule.ancestors_strings",
            bundle(metadata: ["Ancestors": .array([.boolean(true)])]),
            bundle(metadata: ["Ancestors": .array([.string("com.apple.dt.unit.base")])])
        ),
        (
            "rule.options_valid",
            bundle(metadata: ["Options": .array([.dictionary([:])])]),
            // The boundary: an option with no Type is the default plain-text option.
            bundle(metadata: ["Options": .array([.dictionary(["Identifier": .string("productName")])])])
        ),
        (
            "rule.definitions_valid",
            bundle(metadata: ["Definitions": .dictionary(["out.swift": .boolean(true)])]),
            // The boundary: a Definition may be a plain string or a dictionary with a string Path.
            bundle(
                metadata: ["Definitions": .dictionary([
                    "inline.swift": .string("let x = 1"),
                    "copied.swift": .dictionary(["Path": .string("main.swift")]),
                ])],
            )
        ),
        (
            "rule.targets_valid",
            bundle(metadata: ["Targets": .array([.dictionary(["ProductType": .boolean(true)])])]),
            // The boundary: a target with no ProductType at all is valid.
            bundle(metadata: ["Targets": .array([.dictionary([:])])])
        ),
    ]

    @Test(arguments: Self.defaultRuleCases.map(\.code))
    func defaultRuleFires(code: String) throws {
        let fixture = try #require(Self.defaultRuleCases.first { $0.code == code }?.failing)
        let errors = Validator<XcodeTemplateBundle>.defaultTemplateValidator.run(fixture)
        #expect(errors.map(\.code) == [code])
    }

    @Test(arguments: Self.defaultRuleCases.map(\.code))
    func defaultRuleStaysQuiet(code: String) throws {
        let fixture = try #require(Self.defaultRuleCases.first { $0.code == code }?.nearMiss)
        #expect(Validator<XcodeTemplateBundle>.defaultTemplateValidator.run(fixture).isEmpty)
    }

    // MARK: The off-default file rule, isolated on blank

    @Test func fileContentRuleBothDirections() {
        let validator = Validator<XcodeTemplateBundle>.blank
            .validating(Validation<FileInfo, XcodeTemplateBundle>.contentNotEmpty)
        let failing = Self.bundle(files: ["empty.swift": FileInfo(type: "text", content: "")])
        let errors = validator.run(failing)
        #expect(errors.map(\.code) == ["rule.file_content_not_empty"])
        #expect(errors.map { $0.codingPath.map(\.stringValue) } == [["files", "empty.swift"]])
        let nearMiss = Self.bundle(files: ["one.swift": FileInfo(type: "text", content: " ")])
        #expect(validator.run(nearMiss).isEmpty)
    }

    // MARK: Diagnostic rules, failing and near-miss fixtures

    static let diagnosticRuleCases: [(code: String, failing: XcodeTemplateBundle, nearMiss: XcodeTemplateBundle)] = [
        (
            "rule.paths_case_consistent",
            bundle(
                metadata: ["Definitions": .dictionary(["readme.md": .string("hello")])],
                files: ["Readme.md": FileInfo(type: "text", content: "hi")],
            ),
            bundle(
                metadata: ["Definitions": .dictionary(["Readme.md": .string("hello")])],
                files: ["Readme.md": FileInfo(type: "text", content: "hi")],
            )
        ),
        (
            "rule.options_complete",
            bundle(metadata: ["Options": .array([.dictionary([
                "Identifier": .string("kind"),
                "Type": .string("popup"),
                "Values": .array([.string("A"), .string("B")]),
                "Default": .string("C"),
            ])])]),
            // The boundary: the default is exactly a declared value and titles match values.
            bundle(metadata: ["Options": .array([.dictionary([
                "Identifier": .string("kind"),
                "Type": .string("popup"),
                "Values": .array([.string("A"), .string("B")]),
                "ValueTitles": .array([.string("First"), .string("Second")]),
                "Default": .string("B"),
            ])])])
        ),
        (
            "rule.references_resolve",
            bundle(metadata: ["Nodes": .array([.string("Missing.swift")])]),
            // The boundary: the node resolves to a physical file and the macro to an option.
            bundle(
                metadata: [
                    "Nodes": .array([.string("main.swift")]),
                    "Options": .array([.dictionary(["Identifier": .string("zzz")])]),
                ],
                files: ["main.swift": FileInfo(type: "text", content: "___VARIABLE_zzz___")],
            )
        ),
    ]

    @Test(arguments: Self.diagnosticRuleCases.map(\.code))
    func diagnosticRuleFires(code: String) throws {
        let fixture = try #require(Self.diagnosticRuleCases.first { $0.code == code }?.failing)
        let errors = Validator<XcodeTemplateBundle>.diagnosticValidator.run(fixture)
        #expect(errors.map(\.code) == [code])
    }

    @Test(arguments: Self.diagnosticRuleCases.map(\.code))
    func diagnosticRuleStaysQuiet(code: String) throws {
        let fixture = try #require(Self.diagnosticRuleCases.first { $0.code == code }?.nearMiss)
        #expect(Validator<XcodeTemplateBundle>.diagnosticValidator.run(fixture).isEmpty)
    }

    // MARK: BundleFinding codes, the lint vocabulary, both directions

    static let findingCases: [(code: String, findings: @Sendable (XcodeTemplateBundle) -> [BundleFinding], failing: XcodeTemplateBundle, nearMiss: XcodeTemplateBundle)] = [
        (
            "case_collision",
            { $0.caseCollisionFindings },
            bundle(
                metadata: ["Definitions": .dictionary(["readme.md": .string("hello")])],
                files: ["Readme.md": FileInfo(type: "text", content: "hi")],
            ),
            bundle(files: ["Readme.md": FileInfo(type: "text", content: "hi")])
        ),
        (
            "node_unresolved_definition",
            { $0.referentialIntegrityFindings },
            bundle(metadata: ["Nodes": .array([.string("Missing.swift")])]),
            bundle(metadata: ["Nodes": .array([.string("main.swift")])])
        ),
        (
            "definition_path_missing",
            { $0.referentialIntegrityFindings },
            bundle(metadata: ["Definitions": .dictionary(["out.swift": .dictionary(["Path": .string("gone.swift")])])]),
            bundle(metadata: ["Definitions": .dictionary(["out.swift": .dictionary(["Path": .string("main.swift")])])])
        ),
        (
            "macro_names_no_option",
            { $0.referentialIntegrityFindings },
            bundle(files: ["main.swift": FileInfo(type: "text", content: "___VARIABLE_zzz___")]),
            // The boundary: an implicit variable needs no declared option.
            bundle(files: ["main.swift": FileInfo(type: "text", content: "___VARIABLE_productName___")])
        ),
        (
            "option_default_not_in_values",
            { $0.optionCompletenessFindings },
            bundle(metadata: ["Options": .array([.dictionary([
                "Identifier": .string("kind"), "Type": .string("popup"),
                "Values": .array([.string("A")]), "Default": .string("B"),
            ])])]),
            bundle(metadata: ["Options": .array([.dictionary([
                "Identifier": .string("kind"), "Type": .string("popup"),
                "Values": .array([.string("A")]), "Default": .string("A"),
            ])])])
        ),
        (
            "option_valuetitles_mismatch",
            { $0.optionCompletenessFindings },
            bundle(metadata: ["Options": .array([.dictionary([
                "Identifier": .string("kind"),
                "Values": .array([.string("A"), .string("B")]),
                "ValueTitles": .array([.string("First")]),
            ])])]),
            bundle(metadata: ["Options": .array([.dictionary([
                "Identifier": .string("kind"),
                "Values": .array([.string("A"), .string("B")]),
                "ValueTitles": .array([.string("First"), .string("Second")]),
            ])])])
        ),
        (
            "option_rofv_unknown_value",
            { $0.optionCompletenessFindings },
            bundle(metadata: ["Options": .array([.dictionary([
                "Identifier": .string("kind"),
                "Values": .array([.string("A")]),
                "RequiredOptionsForValues": .dictionary(["B": .array([.string("other")])]),
            ])])]),
            bundle(metadata: ["Options": .array([.dictionary([
                "Identifier": .string("kind"),
                "Values": .array([.string("A")]),
                "RequiredOptionsForValues": .dictionary(["A": .array([.string("other")])]),
            ])])])
        ),
    ]

    @Test(arguments: Self.findingCases.map(\.code))
    func findingFires(code: String) throws {
        let entry = try #require(Self.findingCases.first { $0.code == code })
        #expect(entry.findings(entry.failing).map(\.code) == [code])
    }

    @Test(arguments: Self.findingCases.map(\.code))
    func findingStaysQuiet(code: String) throws {
        let entry = try #require(Self.findingCases.first { $0.code == code })
        #expect(entry.findings(entry.nearMiss).isEmpty)
    }

    // MARK: The configuration pin, exact ordered descriptions

    @Test func configurationPinExactDescriptions() {
        #expect(Validator<XcodeTemplateBundle>.blank.validationDescriptions.isEmpty)
        #expect(Validator<XcodeTemplateBundle>.defaultTemplateValidator.validationDescriptions == [
            "Project template identifier is not empty",
            "Template Kind is valid",
            "Template Ancestors is an array of strings",
            "Template Options are valid",
            "Template Definitions are valid",
            "Template Targets are valid",
        ])
        #expect(Validator<XcodeTemplateBundle>.diagnosticValidator.validationDescriptions == [
            "Template file paths are case-consistent (portable to case-sensitive filesystems)",
            "Template options are complete (selectable defaults, matched value titles, valid value references)",
            "Template references resolve (nodes, definition paths, content macros)",
        ])
        let trimmed = Validator<XcodeTemplateBundle>.defaultTemplateValidator
            .withoutValidating(describedAs: "Template Targets are valid")
        #expect(trimmed.validationDescriptions.count == 5)
        #expect(!trimmed.validationDescriptions.contains("Template Targets are valid"))
    }

    // MARK: The machinery's own negatives

    @Test func optionalAndForeignSubjectsYieldNoErrors() {
        let document = Self.bundle()
        let fileRule = AnyValidation(Validation<FileInfo, XcodeTemplateBundle>.contentNotEmpty)
        let optionalInfo: FileInfo? = FileInfo(type: "text", content: "")
        #expect(fileRule.apply(to: optionalInfo as Any, at: [], in: document).isEmpty, "an optional never satisfies the wrapped subject type")
        #expect(fileRule.apply(to: "not a file", at: [], in: document).isEmpty, "a foreign type never trips the rule")
    }

    @Test func falsePredicateYieldsNoErrors() {
        let gated = Validation<XcodeTemplateBundle, XcodeTemplateBundle>(
            description: "never runs",
            code: "rule.never",
            check: { _ in false },
            when: { _ in false },
        )
        let errors = Validator<XcodeTemplateBundle>.blank.validating(gated).run(Self.bundle())
        #expect(errors.isEmpty, "a false predicate gates the check off entirely")
    }

    @Test func sameValueTwiceYieldsTwoErrors() {
        let validator = Validator<XcodeTemplateBundle>.blank
            .validating(Validation<FileInfo, XcodeTemplateBundle>.contentNotEmpty)
        let document = Self.bundle(files: [
            "a.swift": FileInfo(type: "text", content: ""),
            "b.swift": FileInfo(type: "text", content: ""),
        ])
        let errors = validator.run(document)
        #expect(errors.map(\.code) == ["rule.file_content_not_empty", "rule.file_content_not_empty"], "the positive control: identical offenders each report")
        #expect(errors.map { $0.codingPath.map(\.stringValue) } == [["files", "a.swift"], ["files", "b.swift"]], "the sorted walk keeps the error order deterministic")
    }

    // MARK: A many-error bundle reports its complete list in walk order

    @Test func manyErrorBundleReportsTheCompleteListInOrder() {
        let document = Self.bundle(
            identifier: "",
            metadata: [
                "Ancestors": .array([.boolean(true)]),
                "Targets": .array([.dictionary(["ProductType": .boolean(true)])]),
            ],
        )
        let errors = Validator<XcodeTemplateBundle>.defaultTemplateValidator.run(document)
        #expect(errors.map(\.code) == [
            "rule.identifier_not_empty",
            "rule.ancestors_strings",
            "rule.targets_valid",
        ])
        #expect(errors.allSatisfy { error in error.codingPath.isEmpty }, "bundle-level rules report at the root")
    }

    // MARK: The meta-test: coverage equals the registries, exactly

    @Test func everyDeclaredCodeHasItsFixtures() {
        let ruleCovered = Self.defaultRuleCases.map(\.code)
            + ["rule.file_content_not_empty"]
            + Self.diagnosticRuleCases.map(\.code)
        #expect(ruleCovered.count == Set(ruleCovered).count, "one fixture pair per rule code")
        #expect(
            Set(ruleCovered) == Set(TemplateValidationCodes.allRuleCodes),
            "uncovered: \(Set(TemplateValidationCodes.allRuleCodes).subtracting(ruleCovered).sorted()); unregistered: \(Set(ruleCovered).subtracting(TemplateValidationCodes.allRuleCodes).sorted())",
        )

        let findingCovered = Self.findingCases.map(\.code)
        #expect(findingCovered.count == Set(findingCovered).count, "one fixture pair per finding code")
        #expect(
            Set(findingCovered) == Set(TemplateValidationCodes.allFindingCodes),
            "uncovered: \(Set(TemplateValidationCodes.allFindingCodes).subtracting(findingCovered).sorted()); unregistered: \(Set(findingCovered).subtracting(TemplateValidationCodes.allFindingCodes).sorted())",
        )
    }
}
