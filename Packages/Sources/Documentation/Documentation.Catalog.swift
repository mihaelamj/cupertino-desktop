import Foundation
import Localization

public extension Documentation {
    /// The knowledge base: every name the language and the template vocabulary contain. The Swift
    /// side carries STRUCTURE only (which names exist, their kind, the family folding); all human
    /// text lives in the locale resources (`help-<locale>.json`, see `Strings`), English being just
    /// the first language. Corpus-grounded: the doc gate proves every `let` key and every macro
    /// occurring in any of the 10,117 corpus templates resolves to an entry here.
    enum Catalog {
        // MARK: Vocabulary (names only; text comes from Strings)

        public static let keywordNames = ["template", "let", "option", "unit", "node", "directory"]

        /// TemplateInfo top-level keys (the corpus-mined 40).
        public static let manifestKeyNames = [
            "Identifier", "Kind", "Ancestors", "InjectionTargets", "Concrete", "Components",
            "Name", "Title", "Description", "Summary", "Image", "Icon", "SortOrder", "Platforms",
            "Category", "HiddenFromChooser", "HiddenFromLibrary", "ChooserOnly", "ProjectOnly",
            "TargetOnly", "DefaultCompletionName", "NameOfInitialFileForEditor",
            "Nodes", "Definitions", "Targets", "Project", "MainTemplateFile", "BuildableType",
            "AllowedTypes", "PackageType", "SupportsSwiftPackage", "Executables",
            "SuppressTopLevelGroup", "LocalizedByDefault", "IsUnitTest",
            "NSSupportsSuddenTermination", "MacOSSDKVersionMin",
            "Options", "OptionConstraints", "RequiredOptions", "AssociatedTargetSpecification",
            "Macros", "Ancillary",
        ]

        /// Option sub-keys (the corpus-mined 24, plus the DSL's view of them).
        public static let optionKeyNames = [
            "Identifier", "Type", "Name", "Description", "Default", "Values", "ValueTitles",
            "Required", "SortOrder", "Placeholder", "EmptyReplacement", "SpecialType", "Indented",
            "Units", "Variables", "MainTemplateFiles", "AllowedTypes", "FallbackHeader",
            "Suffixes", "Value", "NotPersisted", "RequiredOptions", "RequiredOptionsForValues",
            "Override", "ConditionalOverride", "AllowedValues", "Ancillary",
        ]

        /// Keys inside node blocks and Definitions dicts (incl. corpus-discovered era keys and the
        /// DSL's authoring markers).
        public static let definitionKeyNames = [
            "content", "binary", "Path", "Group", "TargetIndices", "OmitFromProject", "SortOrder",
            "Beginning", "End", "Indent", "SubstituteMacros", "AssetGeneration",
            "BuildAttributes", "TargetIdentifiers", "OmitFromProjectStructure", "PathType",
            "IsPackageReference", "IsTopLevel", "LinkPackageProducts", "New item",
            "_isArray", "_isEmptyArray", "_isString",
        ]

        /// Unit-scope derived-variable bindings (corpus-discovered: `Units > <value> > <name>`).
        public static let unitKeyNames = [
            "moduleNamePrefixForClasses", "audioUnitTypeCode", "audioUnitTypeTags",
        ]

        public static let optionTypeValueNames = [
            "checkbox", "popup", "text", "class", "static", "combo", "buildSetting",
        ]

        /// Core macro spellings (canonical; families as `*` wildcards).
        public static let coreMacroNames = [
            "___PACKAGENAME___", "___PACKAGENAMEASIDENTIFIER___", "___PACKAGENAMEASRFC1034IDENTIFIER___",
            "___PACKAGENAMEASXML___", "___PACKAGENAMEPREVIEWCONTENT___", "___PARENTPACKAGENAME___",
            "___PROJECTNAME___", "___PROJECTNAMEASIDENTIFIER___", "___PROJECTNAMEASXML___",
            "___PRODUCTNAME___", "___TARGETNAME___", "___BUNDLEIDENTIFIER___",
            "___FILEBASENAME___", "___FILEBASENAMEASIDENTIFIER___", "___FILENAME___",
            "___FILEEXTENSION___", "___FILEHEADER___",
            "___ORGANIZATIONNAME___", "___FULLUSERNAME___", "___USERNAME___",
            "___DATE___", "___TIME___", "___YEAR___", "___COPYRIGHT___",
            "___NSHUMANREADABLECOPYRIGHTPLIST___",
            "___UUID___", "___UUID1___", "___UUID2___", "___UUIDASIDENTIFIER___",
            "___VARIABLE_*___", "___VARIABLE___", "___IMPORTHEADER_*___", "___ASSOCIATEDTARGET_*___",
            "___OPTION_*___",
            "___SOURCELANGUAGE___", "___SUPERCLASSNAME___", "___IMPORTFILENAME___", "___IMPORTS___",
            "___AR___", "___RP___", "___RT___", "___OBJCATTRIBUTE___",
            "___ACCENTCOLOR___", "___PLACEHOLDERICON___",
            "___DEVELOPMENTTEAMIDENTIFIER___", "___DEFAULT_MACOS_CODE_SIGN_IDENTITY___",
            "___DEFAULTTOOLCHAINSWIFTVERSION___", "___TOOLSVERSION___",
            "___BESTMACOSVERSION___", "___BESTDRIVERKITVERSION___",
            "___RUNNINGMACOSVERSION___", "___RUNNINGOSXVERSION___", "___RUNNINGDARWINVERSION___",
            "___MACRONAME___", "___MACRO_A___", "___MACRO_B___", "___NAME___", "___UNKNOWN_VARIABLE___",
            "___CUSTOM_DIALOG___", "___AUXILIARY_CONTENT___", "___MORE_CONFORMANCES___",
            "___PARAMETERS___", "___PREDICTIONS___", "___RESULT_DECLARATION___", "___RESULT_VALUE___",
            "___ACTION_CONFIGURATION___", "___LINK_ACTION___", "___LINK_ACTION_TITLE___",
            "___LINK_ACTION_DESCRIPTION___", "___TEST_PLAN_INITIAL_CONFIGURATION_UUID___",
        ]

        /// Domain families whose content the engine synthesizes from a user-configured model.
        public static let generatedContentMacroNames = [
            "___COREDATAFILECOMMENTEPILOGUE___", "___COREDATAMANAGEDOBJECTCLASSIMPORT___",
            "___COREDATAMANAGEDOBJECTCLASSREFERENCES___", "___COREDATAMANAGEDOBJECTIMPORTEDHEADERS___",
            "___COREDATAMANAGEDOBJECTIMPORTEDMODULES___", "___COREDATAMANAGEDOBJECTSUPERCLASSIMPORT___",
            "___COREDATAMANAGEDOBJECTSUPERCLASS___", "___COREDATAPROPERTYDECLARATIONS___",
            "___COREDATAPROPERTYIMPLEMENTATIONS___", "___COREDATA_DATAMODELNAME_ALPHA_ONLY___",
            "___COREDATA_DATAMODELNAME___", "___COREDATA_DATAMODEL_MANAGEDOBJECTCLASSES_IMPLEMENTATIONS___",
            "___COREDATA_DATAMODEL_MANAGEDOBJECTCLASSES_IMPORTS___", "___COREDATA_DATAMODEL_MANAGEDOBJECTCLASSES_INTERFACES___",
            "___COREDATA_DATAMODEL_MANAGEDOBJECTCLASSES_REFERENCES___", "___COREDATA_MANAGEDOBJECT_CLASS___",
            "___INTENTRESPONSE_CODES___", "___INTENTRESPONSE_CUSTOM_CODES___",
            "___INTENTRESPONSE_CUSTOM_INITIALIZER_DECLARATIONS___", "___INTENTRESPONSE_CUSTOM_INITIALIZER_IMPLEMENTATIONS___",
            "___INTENTRESPONSE_PROPERTY_DECLARATIONS___", "___INTENTRESPONSE_PROPERTY_IMPLEMENTATIONS___",
            "___INTENT_AVAILABILITY___", "___INTENT_CLASS_NAME___", "___INTENT_ENUMS___",
            "___INTENT_IMPORT_STATEMENTS___", "___INTENT_NAME___", "___INTENT_PROPERTY_DECLARATIONS___",
            "___INTENT_PROPERTY_IMPLEMENTATIONS___", "___INTENT_SUBCLASS___", "___INTENT_TYPE___",
            "___SWIFTDATA_CLASS_ATTRIBUTES___", "___SWIFTDATA_CLASS_FILE_COMMENT_EPILOGUE___",
            "___SWIFTDATA_CLASS_IMPORTED_MODULES___", "___SWIFTDATA_CLASS_INIT___",
            "___SWIFTDATA_CLASS_NAME___", "___SWIFTDATA_CLASS_PROPERTY_IMPLEMENTATIONS___",
            "___SWIFTDATA_SUPERCLASS_NAME___", "___SWIFTDATA_UNSUPPORTED_IN_SWIFT_DATA___",
            "___APP_ENTITY_DISPLAY_NAME___", "___APP_ENTITY_PROPERTIES___", "___APP_ENTITY_QUERY_TYPE___",
            "___APP_ENTITY_QUERY___", "___APP_ENTITY_STRING_QUERY_FUNCTION___", "___APP_ENTITY___",
            "___APP_ENUM_CASES___", "___APP_ENUM_CASE_DISPLAY_NAMES___", "___APP_ENUM_DISPLAY_NAME___", "___APP_ENUM___",
            "___UNIT_TEST_BASE_CLASS___", "___UNIT_TEST_FRAMEWORK_NAME___", "___UNIT_TEST_SYMBOL_PREFIX___",
        ]

        public static let modifierNames = [
            "identifier", "c99extidentifier", "RFC1034Identifier", "rfc1034identifier",
            "bundleIdentifier", "xml", "XML", "lower", "lowercased", "uppercaseFirst",
            "quoteIfNeeded", "deletingLastPathComponent",
        ]

        // MARK: Entry construction (text resolved per locale)

        public static func keywords(locale: String = "en") -> [String: Entry] {
            entries(names: keywordNames, kind: .keyword, prefix: "keyword.", locale: locale)
        }

        public static func manifestKeys(locale: String = "en") -> [String: Entry] {
            entries(names: manifestKeyNames, kind: .manifestKey, prefix: "key.template.", locale: locale)
        }

        public static func optionKeys(locale: String = "en") -> [String: Entry] {
            entries(names: optionKeyNames, kind: .optionKey, prefix: "key.option.", locale: locale)
        }

        public static func definitionKeys(locale: String = "en") -> [String: Entry] {
            entries(names: definitionKeyNames, kind: .definitionKey, prefix: "key.definition.", locale: locale)
        }

        public static func optionTypeValues(locale: String = "en") -> [String: Entry] {
            entries(names: optionTypeValueNames, kind: .optionTypeValue, prefix: "type.", locale: locale)
        }

        public static func macros(locale: String = "en") -> [String: Entry] {
            entries(names: coreMacroNames + generatedContentMacroNames, kind: .macro, prefix: "macro.", locale: locale)
        }

        // MARK: Lookup

        public static func lookup(keyword name: String, locale: String = "en") -> Entry? {
            keywordNames.contains(name) ? entry(name: name, kind: .keyword, key: "keyword." + name, locale: locale) : nil
        }

        public static func lookup(letKey name: String, context: Context, locale: String = "en") -> Entry? {
            switch context {
            case .template:
                return manifestKeyNames.contains(name) ? entry(name: name, kind: .manifestKey, key: "key.template." + name, locale: locale) : nil
            case .option:
                return optionKeyNames.contains(name) ? entry(name: name, kind: .optionKey, key: "key.option." + name, locale: locale) : nil
            case .unit, .node:
                if unitKeyNames.contains(name) {
                    return entry(name: name, kind: .contextual, key: "key.unit." + name, locale: locale)
                }
                if definitionKeyNames.contains(name) {
                    return entry(name: name, kind: .definitionKey, key: "key.definition." + name, locale: locale)
                }
                return manifestKeyNames.contains(name) ? entry(name: name, kind: .manifestKey, key: "key.template." + name, locale: locale) : nil
            }
        }

        public static func lookup(macro raw: String, locale: String = "en") -> Entry? {
            let name = normalize(macro: raw)
            guard coreMacroNames.contains(name) || generatedContentMacroNames.contains(name) || name == "___*___" else { return nil }
            return entry(name: name, kind: .macro, key: "macro." + name, locale: locale)
        }

        public static func lookup(optionTypeValue name: String, locale: String = "en") -> Entry? {
            optionTypeValueNames.contains(name) ? entry(name: name, kind: .optionTypeValue, key: "type." + name, locale: locale) : nil
        }

        public static func lookup(modifier name: String, locale: String = "en") -> String? {
            Strings.text(forKey: "modifier." + name, locale: locale)?.title
        }

        /// The construct a `let` binding sits in; decides which key vocabulary applies.
        public enum Context: Sendable {
            case template, option, unit, node
        }

        // MARK: Normalization

        /// Fold a raw macro occurrence onto its catalog name: strip `:modifier` tails, collapse
        /// underscore-run artifacts, and map parameterized families onto their `*` wildcard.
        public static func normalize(macro raw: String) -> String {
            var name = raw
            // Trim surrounding underscore runs to exactly three (adjacent-macro artifacts).
            while name.hasPrefix("____") {
                name.removeFirst()
            }
            while name.hasSuffix("____") {
                name.removeLast()
            }
            // Strip a :modifier tail (keep the UUID:<key> family intact).
            if let colon = name.firstIndex(of: ":"), !name.hasPrefix("___UUID:") {
                name = String(name[..<colon]) + "___"
            }
            for family in ["___VARIABLE_", "___IMPORTHEADER_", "___ASSOCIATEDTARGET_", "___OPTION_"] {
                if name.hasPrefix(family), name != family + "*___", name.count > family.count + 3 {
                    return family + "*___"
                }
            }
            if name.hasPrefix("___UUID:") { return "___UUID___" }
            // Case-spelled variants (___filebasename___, ___ProjectName___) document as their canonical form.
            let upper = name.uppercased()
            if upper != name, coreMacroNames.contains(upper) || generatedContentMacroNames.contains(upper) {
                return upper
            }
            return name
        }

        /// Underscore-separated spellings derive a friendly name mechanically:
        /// `___APP_ENTITY_DISPLAY_NAME___` becomes "App Entity Display Name". Used when a locale
        /// table carries no display override.
        static func derivedDisplayName(for macro: String) -> String {
            let trimmed = macro.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            let words = trimmed.split(separator: "_").map { word -> String in
                let lower = word.lowercased()
                switch lower {
                case "coredata": return "Core Data"
                case "swiftdata": return "SwiftData"
                case "uuid": return "UUID"
                default: return lower.prefix(1).uppercased() + lower.dropFirst()
                }
            }
            return words.joined(separator: " ")
        }

        // MARK: Internal

        private static func entries(names: [String], kind: Entry.Kind, prefix: String, locale: String) -> [String: Entry] {
            var result: [String: Entry] = [:]
            for name in names {
                result[name] = entry(name: name, kind: kind, key: prefix + name, locale: locale)
            }
            return result
        }

        /// An entry always exists for a known name; a missing locale text degrades to the derived
        /// display name with empty help rather than disappearing (the en table test enforces that
        /// this never actually happens for `en`).
        private static func entry(name: String, kind: Entry.Kind, key: String, locale: String) -> Entry {
            let text = Strings.text(forKey: key, locale: locale)
            let fallbackDisplay = kind == .macro ? derivedDisplayName(for: name) : name
            return Entry(
                kind: kind,
                name: name,
                displayName: text?.display ?? fallbackDisplay,
                title: text?.title ?? name,
                body: text?.body ?? "",
            )
        }
    }
}

public extension Documentation.Catalog {
    /// The template kind identifiers the corpus ships, in catalog order. Display names
    /// live in the catalog under `kindname.<identifier>`.
    static let kindIdentifierNames = [
        "Xcode.Xcode3.ProjectTemplateUnitKind",
        "Xcode.IDEFoundation.TextSubstitutionFileTemplateKind",
        "Xcode.IDEKit.TextSubstitutionFileTemplateKind",
        "Xcode.IDEFoundation.TextSubstitutionPlaygroundTemplateKind",
        "Xcode.IDESwiftPackageSupport.PackageTemplateKind",
        "Xcode.IDESwiftPackageSupport.PackageProjectTemplateKind",
        "Xcode.IDETestPlanEditor.TestPlanTemplateKind",
        "Xcode.IDESwiftPackageUI.TextSubstitutionPlaygroundsAppTemplateKind",
        "Xcode.IDESwiftPackageCore.TextSubstitutionPlaygroundsAppTemplateKind",
        "Xcode.IDEKit.PlaygroundWithPlatformChoice",
        "Xcode.IDEKit.RefactoringFileTemplateKind.NewSuperclass",
        "Xcode.IDECoreDataModeler.ManagedObjectTemplateKind",
        "Xcode.IDEIntentBuilderEditor.IntentTemplateKind",
        "Xcode.IDEIntentBuilderEditor.LinkActionTemplateKind",
        "Xcode.IDEIntentBuilderEditor.TransientAppEntityTemplateKind",
        "Xcode.IDEIntentBuilderEditor.AppEnumerationTemplateKind",
        "Xcode.IDEIntentBuilderEditor.AppEntityTemplateKind",
    ]

    /// Display-only shortening for arbitrary text: macro spellings render as their
    /// friendly names (a `:modifier` tail composes as a parenthesized suffix) and
    /// template kind identifiers as their short names. The original text remains the
    /// truth everywhere; callers show the result and keep the source. Returns nil when
    /// nothing shortened, so call sites skip work and storage.
    static func display(for text: String, locale: String = "en") -> String? {
        var result = text
        var changed = false

        for identifier in kindIdentifierNames where result.contains(identifier) {
            guard let friendly = Localization.Strings.string(forKey: "kindname." + identifier, locale: locale) else { continue }
            result = result.replacingOccurrences(of: identifier, with: friendly)
            changed = true
        }

        // Macro occurrences, replaced back to front so ranges stay valid.
        let pattern = "___[A-Za-z][A-Za-z0-9_]*?(?::[A-Za-z0-9]+)?___"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return changed ? result : nil
        }
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let raw = String(result[range])
            guard let entry = lookup(macro: raw, locale: locale), entry.displayName != raw else { continue }
            var friendly = entry.displayName
            if let colon = raw.firstIndex(of: ":"), !raw.hasPrefix("___UUID:") {
                let modifier = String(raw[raw.index(after: colon)...].dropLast(3))
                friendly += " (" + (lookup(modifier: modifier, locale: locale) ?? modifier) + ")"
            }
            result.replaceSubrange(range, with: friendly)
            changed = true
        }
        return changed ? result : nil
    }
}
