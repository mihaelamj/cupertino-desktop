import Foundation
import SharedModels

public enum TemplateValidationCodes {
    /// Every ValidationError code the validators can produce, the coverage truth for the
    /// exhaustive rule tests: a new rule lands here and in a both-directions test in the
    /// same change, or the meta-test names the gap.
    public static let allRuleCodes: [String] = [
        "rule.identifier_not_empty", "rule.kind_valid", "rule.ancestors_strings",
        "rule.options_valid", "rule.definitions_valid", "rule.targets_valid",
        "rule.file_content_not_empty",
        "rule.paths_case_consistent", "rule.options_complete", "rule.references_resolve",
    ]

    /// Every BundleFinding code the lint accessors can produce, under the same law.
    public static let allFindingCodes: [String] = [
        "case_collision",
        "node_unresolved_definition", "definition_path_missing", "macro_names_no_option",
        "option_default_not_in_values", "option_valuetitles_mismatch", "option_rofv_unknown_value",
    ]
}

public extension Validation where Subject == XcodeTemplateBundle, Document == XcodeTemplateBundle {
    static var identifierNotEmpty: Validation<XcodeTemplateBundle, XcodeTemplateBundle> {
        Validation(
            description: "Project template identifier is not empty",
            code: "rule.identifier_not_empty",
            check: { context in
                // Only a project unit template requires an Identifier. File, playground, and test-plan
                // templates legitimately have none (they are keyed on Kind alone), so an absent or empty
                // Identifier is valid for those.
                let kind = context.subject.metadata["Kind"]?.stringValue ?? ""
                if kind == "Xcode.Xcode3.ProjectTemplateUnitKind" {
                    return !context.subject.identifier.isEmpty
                }
                return true
            },
        )
    }

    static var kindIsValid: Validation<XcodeTemplateBundle, XcodeTemplateBundle> {
        Validation(
            description: "Template Kind is valid",
            code: "rule.kind_valid",
            check: { context in
                // Kind is OPTIONAL: base / partial templates (Ancestors-only, contributing definitions to
                // a parent) ship with no Kind at all. When present, Kind is a string naming the template
                // engine; Apple's vocabulary is open and not all values end in "Kind" (e.g.
                // `Xcode.IDEKit.PlaygroundWithPlatformChoice`), so accept any non-empty string rather than
                // a fixed allow-list. Only a present, non-string, or empty Kind is malformed.
                guard let kindValue = context.subject.metadata["Kind"] else { return true }
                guard let kindString = kindValue.stringValue else { return false }
                return !kindString.isEmpty
            },
        )
    }

    static var ancestorsAreStrings: Validation<XcodeTemplateBundle, XcodeTemplateBundle> {
        Validation(
            description: "Template Ancestors is an array of strings",
            code: "rule.ancestors_strings",
            check: { context in
                guard let ancestorsVal = context.subject.metadata["Ancestors"] else { return true }
                guard let arr = ancestorsVal.arrayValue else { return false }
                return arr.allSatisfy { $0.stringValue != nil }
            },
        )
    }

    static var optionsAreValid: Validation<XcodeTemplateBundle, XcodeTemplateBundle> {
        Validation(
            description: "Template Options are valid",
            code: "rule.options_valid",
            check: { context in
                guard let optionsVal = context.subject.metadata["Options"] else { return true }
                guard let optionsArr = optionsVal.arrayValue else { return false }

                for optVal in optionsArr {
                    guard let dict = optVal.dictionaryValue else { return false }
                    guard let optId = dict["Identifier"]?.stringValue, !optId.isEmpty else { return false }
                    // Type is optional: an absent Type means the default option kind (a plain text option),
                    // which is valid and common in real templates. Only reject a Type that is present but
                    // not a string.
                    if let typeVal = dict["Type"], typeVal.stringValue == nil { return false }
                }
                return true
            },
        )
    }

    static var definitionsAreValid: Validation<XcodeTemplateBundle, XcodeTemplateBundle> {
        Validation(
            description: "Template Definitions are valid",
            code: "rule.definitions_valid",
            check: { context in
                guard let defsVal = context.subject.metadata["Definitions"] else { return true }
                guard let dict = defsVal.dictionaryValue else { return false }

                for (_, val) in dict {
                    switch val {
                    case .string:
                        break
                    case let .dictionary(defDict):
                        if let pathVal = defDict["Path"], pathVal.stringValue == nil {
                            return false
                        }
                    default:
                        return false
                    }
                }
                return true
            },
        )
    }

    static var targetsAreValid: Validation<XcodeTemplateBundle, XcodeTemplateBundle> {
        Validation(
            description: "Template Targets are valid",
            code: "rule.targets_valid",
            check: { context in
                guard let targetsVal = context.subject.metadata["Targets"] else { return true }
                guard let arr = targetsVal.arrayValue else { return false }

                for targetVal in arr {
                    guard let dict = targetVal.dictionaryValue else { return false }
                    if let prodType = dict["ProductType"], prodType.stringValue == nil {
                        return false
                    }
                }
                return true
            },
        )
    }
}

public extension Validation where Subject == FileInfo, Document == XcodeTemplateBundle {
    static var contentNotEmpty: Validation<FileInfo, XcodeTemplateBundle> {
        Validation(
            description: "File content is not empty",
            code: "rule.file_content_not_empty",
            check: { context in
                !context.subject.content.isEmpty
            },
        )
    }
}

public extension XcodeTemplateBundle {
    /// Every file path the manifest references, gathered for case-portability checks: the `Definitions`
    /// output keys, their source `Path` values, and the physical file keys.
    var referencedPaths: [String] {
        var paths: [String] = Array(files.keys)
        if case let .dictionary(defs) = metadata["Definitions"] {
            for (outputKey, value) in defs {
                paths.append(outputKey)
                if case let .dictionary(def) = value, case let .string(source) = def["Path"] {
                    paths.append(source)
                }
            }
        }
        return paths
    }

    /// Groups of referenced paths that are equal ignoring case but differ in exact case. Each group is a
    /// portability hazard: it round-trips on a case-insensitive filesystem (macOS) but splits or breaks on
    /// a case-sensitive one (Linux, CI). Empty when the template is case-consistent.
    var pathCaseCollisions: [[String]] {
        var byLowercase: [String: Set<String>] = [:]
        for path in referencedPaths {
            byLowercase[path.lowercased(), default: []].insert(path)
        }
        return byLowercase.values
            .filter { $0.count > 1 }
            .map { $0.sorted() }
            .sorted { ($0.first ?? "") < ($1.first ?? "") }
    }

    /// Variables Xcode provides implicitly at instantiation, so a `___VARIABLE_x___` reference to one needs
    /// no declared option. Derived from the whole corpus: these are exactly the names that appear
    /// unresolved in shipped, working templates (`NameOfVariable` is Apple's own documentation example).
    static let implicitVariables: Set<String> = [
        "productName", "bundleIdentifier", "bundleIdentifierPrefix",
        "persistentContainerClass", "usedWithCloudKitModelAttribute", "classPrefix",
        "NameOfVariable",
    ]

    /// Referential-integrity defects, checked only for a template with no `Ancestors` (inheritance resolves
    /// references across the lineage, which a single bundle cannot see). Each rule was verified corpus-clean
    /// over all 3,507 ancestor-free templates, so any hit is a genuine dangling reference:
    /// - a `Nodes` entry that resolves to no `Definition` (exact, base-name, or `*` wildcard) and no
    ///   physical file or directory;
    /// - a `Definition` `Path` that resolves to no physical file or directory (case-insensitive; case
    ///   mismatches are the separate case-consistency diagnostic);
    /// - a `___VARIABLE_x___` macro in file content naming neither a declared option nor an implicit
    ///   variable.
    var referentialIntegrityIssues: [String] {
        referentialIntegrityFindings.map(\.text)
    }

    var referentialIntegrityFindings: [BundleFinding] {
        guard metadata["Ancestors"] == nil else { return [] }
        var issues: [BundleFinding] = []

        // Gather definitions (top-level and per unit spec), their Paths, and the option identifiers.
        var definitionKeys = Set<String>()
        var definitionPaths: [String] = []
        func collect(_ value: PropertyListValue?) {
            guard case let .dictionary(defs)? = value else { return }
            for (key, entry) in defs {
                definitionKeys.insert(key)
                if case let .dictionary(def) = entry, case let .string(path)? = def["Path"] {
                    definitionPaths.append(path)
                }
            }
        }
        collect(metadata["Definitions"])
        var optionIdentifiers = Set<String>()
        if case let .array(options)? = metadata["Options"] {
            for option in options {
                guard case let .dictionary(opt) = option else { continue }
                if let id = opt["Identifier"]?.stringValue { optionIdentifiers.insert(id) }
                if case let .dictionary(units)? = opt["Units"] {
                    for unitValue in units.values {
                        let specs: [PropertyListValue] = if case let .array(array) = unitValue { array } else { [unitValue] }
                        for spec in specs {
                            if case let .dictionary(specDict) = spec { collect(specDict["Definitions"]) }
                        }
                    }
                }
            }
        }

        // Physical entries: every file, every directory implied by a file path, every empty directory.
        var physical = Set<String>()
        for path in files.keys {
            physical.insert(path.lowercased())
            var parent = (path as NSString).deletingLastPathComponent
            // Guard against a non-shrinking parent ("/" maps to "/"), which an absolute or malformed key
            // would otherwise turn into an infinite loop.
            while !parent.isEmpty {
                physical.insert(parent.lowercased())
                let next = (parent as NSString).deletingLastPathComponent
                if next == parent { break }
                parent = next
            }
        }
        for dir in emptyDirectories {
            physical.insert(dir.lowercased())
        }

        // Rule 1: every top-level Nodes entry resolves.
        let definitionBases = Set(definitionKeys.map { $0.components(separatedBy: "(").first ?? $0 })
        let wildcardKeys = definitionKeys.filter { $0.contains("*") }.map { $0.components(separatedBy: "(").first ?? $0 }
        if case let .array(nodes)? = metadata["Nodes"] {
            for node in nodes {
                guard case let .string(name) = node else { continue }
                let base = name.components(separatedBy: "(").first ?? name
                if definitionKeys.contains(name) || definitionBases.contains(base) { continue }
                if wildcardKeys.contains(where: { wildcardMatches(pattern: $0, value: base) }) { continue }
                if physical.contains(name.lowercased()) { continue }
                issues.append(BundleFinding(code: "node_unresolved_definition", arguments: [name]))
            }
        }

        // Rule 2: every Definition Path resolves to a physical file or directory.
        for path in definitionPaths where !physical.contains(path.lowercased()) {
            issues.append(BundleFinding(code: "definition_path_missing", arguments: [path]))
        }

        // Rule 3: every ___VARIABLE_x___ macro in text content names a declared option or an implicit variable.
        let known = optionIdentifiers.union(Self.implicitVariables)
        var reportedMacros = Set<String>()
        for (path, info) in files where info.type == "text" {
            for name in Self.variableMacroNames(in: info.content) where !known.contains(name) && !reportedMacros.contains(name) {
                reportedMacros.insert(name)
                issues.append(BundleFinding(code: "macro_names_no_option", arguments: [name, path]))
            }
        }
        // Sort by the source-language rendering, preserving the historical output order.
        return issues.sorted { $0.text < $1.text }
    }

    private func wildcardMatches(pattern: String, value: String) -> Bool {
        let parts = pattern.components(separatedBy: "*")
        guard parts.count > 1 else { return pattern == value }
        var remainder = Substring(value)
        for (index, part) in parts.enumerated() {
            if part.isEmpty { continue }
            if index == 0 {
                guard remainder.hasPrefix(part) else { return false }
                remainder = remainder.dropFirst(part.count)
            } else if index == parts.count - 1 {
                guard remainder.hasSuffix(part) else { return false }
                remainder = remainder.dropLast(part.count)
            } else {
                guard let range = remainder.range(of: part) else { return false }
                remainder = remainder[range.upperBound...]
            }
        }
        return true
    }

    /// The `x` of every `___VARIABLE_x___` or `___VARIABLE_x:modifier___` occurrence in `text`.
    static func variableMacroNames(in text: String) -> [String] {
        var names: [String] = []
        var search = text[...]
        while let start = search.range(of: "___VARIABLE_") {
            let after = search[start.upperBound...]
            guard let end = after.range(of: "___") else { break }
            let token = after[..<end.lowerBound]
            let name = token.components(separatedBy: ":").first ?? String(token)
            if !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
                names.append(String(name))
            }
            search = after[end.upperBound...]
        }
        return names
    }

    /// Completeness defects in the options that NO valid Apple template exhibits (each was verified at 0
    /// occurrences across the whole 10,117-template corpus, so any occurrence is a genuine authoring bug):
    /// a popup `Default` that is not one of its `Values`; a `ValueTitles` count that does not match the
    /// `Values` count; and a `RequiredOptionsForValues` owner that is not a declared `Value`. Empty when the
    /// options are complete.
    /// The case-collision groups as typed findings (one per group, members joined for display;
    /// paths are language material). `validation.case_collision` renders the standard line,
    /// `validation.case_collision_verbose` the lint command's explanatory variant.
    var caseCollisionFindings: [BundleFinding] {
        pathCaseCollisions.map { group in
            BundleFinding(code: "case_collision", arguments: [group.joined(separator: "  vs  ")])
        }
    }

    var optionCompletenessIssues: [String] {
        optionCompletenessFindings.map(\.text)
    }

    var optionCompletenessFindings: [BundleFinding] {
        var issues: [BundleFinding] = []
        guard case let .array(options) = metadata["Options"] else { return issues }
        for option in options {
            guard case let .dictionary(opt) = option else { continue }
            let id = opt["Identifier"]?.stringValue ?? "?"
            let type = opt["Type"]?.stringValue
            let values = opt["Values"]?.arrayValue?.compactMap(\.stringValue)
            if type == "popup", let values, let dflt = opt["Default"]?.stringValue, !values.contains(dflt) {
                issues.append(BundleFinding(code: "option_default_not_in_values", arguments: [id, dflt, "\(values)"]))
            }
            if let values, let titles = opt["ValueTitles"]?.arrayValue, titles.count != values.count {
                issues.append(BundleFinding(code: "option_valuetitles_mismatch", arguments: [id, String(titles.count), String(values.count)]))
            }
            if let values, case let .dictionary(requiredForValues) = opt["RequiredOptionsForValues"] {
                for owner in requiredForValues.keys.sorted() where !values.contains(owner) {
                    issues.append(BundleFinding(code: "option_rofv_unknown_value", arguments: [id, owner]))
                }
            }
        }
        return issues
    }
}

public extension Validation where Subject == XcodeTemplateBundle, Document == XcodeTemplateBundle {
    /// A DIAGNOSTIC (not a default gate): the template references no path under two different casings. A
    /// Definition whose output key and source `Path` differ only by case (for example FxPlug's
    /// `Base.lproj/MainMenu.xib` vs `base.lproj/MainMenu.xib`) round-trips on macOS but breaks on a
    /// case-sensitive filesystem. Real Apple templates contain this, so it warns rather than rejects.
    static var pathsAreCaseConsistent: Validation<XcodeTemplateBundle, XcodeTemplateBundle> {
        Validation(
            description: "Template file paths are case-consistent (portable to case-sensitive filesystems)",
            code: "rule.paths_case_consistent",
            check: { context in
                context.subject.pathCaseCollisions.isEmpty
            },
        )
    }

    /// A DIAGNOSTIC: the options are complete (a popup Default is selectable, ValueTitles match Values, and
    /// RequiredOptionsForValues owners are declared values). These are corpus-clean invariants, so any
    /// violation is a genuine defect, but it is reported (via `lint`) rather than enforced in the compile
    /// path. See `optionCompletenessIssues`.
    static var optionsAreComplete: Validation<XcodeTemplateBundle, XcodeTemplateBundle> {
        Validation(
            description: "Template options are complete (selectable defaults, matched value titles, valid value references)",
            code: "rule.options_complete",
            check: { context in
                context.subject.optionCompletenessIssues.isEmpty
            },
        )
    }

    /// A DIAGNOSTIC: every reference in an ancestor-free template resolves (nodes to definitions or files,
    /// definition paths to bundle entries, content macros to declared options or implicit variables).
    /// Templates with `Ancestors` are skipped: their references resolve through the lineage, which a single
    /// bundle cannot see. See `referentialIntegrityIssues`.
    static var referencesResolve: Validation<XcodeTemplateBundle, XcodeTemplateBundle> {
        Validation(
            description: "Template references resolve (nodes, definition paths, content macros)",
            code: "rule.references_resolve",
            check: { context in
                context.subject.referentialIntegrityIssues.isEmpty
            },
        )
    }
}

public extension Validator where Document == XcodeTemplateBundle {
    static var defaultTemplateValidator: Validator<XcodeTemplateBundle> {
        Validator(validations: [
            AnyValidation(Validation<XcodeTemplateBundle, XcodeTemplateBundle>.identifierNotEmpty),
            AnyValidation(Validation<XcodeTemplateBundle, XcodeTemplateBundle>.kindIsValid),
            AnyValidation(Validation<XcodeTemplateBundle, XcodeTemplateBundle>.ancestorsAreStrings),
            AnyValidation(Validation<XcodeTemplateBundle, XcodeTemplateBundle>.optionsAreValid),
            AnyValidation(Validation<XcodeTemplateBundle, XcodeTemplateBundle>.definitionsAreValid),
            AnyValidation(Validation<XcodeTemplateBundle, XcodeTemplateBundle>.targetsAreValid),
            // Note: an empty file is valid (an "Empty File" template, a .gitkeep, an empty stub), so the
            // bundle validator does NOT require non-empty content. `contentNotEmpty` remains available for
            // callers that want it, but it is not part of the default template validation.
        ])
    }

    /// DIAGNOSTIC validations: portability and authoring checks that real Apple templates can legitimately
    /// fail, so they are reported (via `lint`) rather than enforced in the compile / decompile path.
    static var diagnosticValidator: Validator<XcodeTemplateBundle> {
        Validator(validations: [
            AnyValidation(Validation<XcodeTemplateBundle, XcodeTemplateBundle>.pathsAreCaseConsistent),
            AnyValidation(Validation<XcodeTemplateBundle, XcodeTemplateBundle>.optionsAreComplete),
            AnyValidation(Validation<XcodeTemplateBundle, XcodeTemplateBundle>.referencesResolve),
        ])
    }
}
