#if !os(WASI)
    import Decompiler
    import Documentation
    import Foundation
    import Lexer
    import Localization
    import PackManager
    import Parser
    import SharedModels
    import TemplateExpander
    import Validation

    let args = CommandLine.arguments

    /// The full command reference. Command syntax is language material (fixed); the header is prose
    /// (catalog-rendered per locale).
    func printUsage(locale: String = "en") {
        print(Localization.render(key: "cli.help.header", locale: locale) ?? "xctemplate: the Xcode template DSL compiler family")
        print("")
        print("  Compile:   xctemplate compile <source_dsl_path> <output_parent_dir>")
        print("  Decompile: xctemplate decompile <xctemplate_dir> <output_dsl_path>")
        print("  Expand:    xctemplate expand <source_dsl_path> <output_dir> [option1=value1 ...] [--trace] [--locale=xx]")
        print("  Lint:      xctemplate lint <xctemplate_dir> [locale]")
        print("  Check:     xctemplate check <source_dsl_path> [locale]")
        print("  AST:       xctemplate ast <source_dsl_path>")
        print("  Options:   xctemplate options <source_dsl_path>")
        print("  Explain:   xctemplate explain <name> [locale]")
        print("  Locales:   xctemplate locales")
        print("  DocCheck:  xctemplate doccheck <source_dsl_path>")
        print("  Doc:       xctemplate doc <source_dsl_path> [locale]")
        print("  Hover:     xctemplate hover <source_dsl_path> <line> <col> [locale]")
        print("  Complete:  xctemplate complete <source_dsl_path> <line> <col> [locale]")
        print("  Doctor:    xctemplate doctor [locale]")
        print("  Help:      xctemplate help [locale]")
    }

    // `help` (also --help, -h): the command reference, exit 0 (asked for, not an error).
    if args.count >= 2, ["help", "--help", "-h"].contains(args[1]) {
        printUsage(locale: args.count >= 3 ? args[2] : "en")
        exit(0)
    }

    // `doctor [locale]` self-diagnoses the installation: the catalog loads, every vocabulary name has
    // help text, the prose templates exist, and a built-in fixture survives the whole engine
    // (compile, decompile, check, expand). The `[ok]`/`[FAIL]` markers are fixed protocol; the prose
    // renders per locale.
    if args.count >= 2, args[1] == "doctor" {
        let locale = args.count >= 3 ? args[2] : "en"
        var failures = 0
        func report(_ ok: Bool, _ key: String, _ arguments: [String] = []) {
            let text = Localization.render(key: key, arguments: arguments, locale: locale)
                ?? Localization.fallback(code: key, arguments: arguments)
            print((ok ? "[ok]   " : "[FAIL] ") + text)
            if !ok { failures += 1 }
        }

        // 1. The String Catalog loads and carries the locales.
        let table = Localization.Strings.table(locale: "en")
        report(!table.isEmpty, "cli.doctor.catalog", [String(table.count)])
        let locales = Localization.Strings.availableLocales()
        report(!locales.isEmpty, "cli.doctor.locales", [locales.joined(separator: ", ")])

        // 2. Every vocabulary name resolves to help text (the doc gate's invariant, checked locally).
        var vocabularyKeys: [String] = []
        vocabularyKeys += Documentation.Catalog.keywordNames.map { "keyword.\($0).title" }
        vocabularyKeys += Documentation.Catalog.manifestKeyNames.map { "key.template.\($0).title" }
        vocabularyKeys += Documentation.Catalog.optionKeyNames.map { "key.option.\($0).title" }
        vocabularyKeys += Documentation.Catalog.definitionKeyNames.map { "key.definition.\($0).title" }
        vocabularyKeys += Documentation.Catalog.unitKeyNames.map { "key.unit.\($0).title" }
        vocabularyKeys += Documentation.Catalog.optionTypeValueNames.map { "type.\($0).title" }
        vocabularyKeys += (Documentation.Catalog.coreMacroNames + Documentation.Catalog.generatedContentMacroNames).map { "macro.\($0).title" }
        let missingVocabulary = vocabularyKeys.filter { table[$0] == nil }
        report(missingVocabulary.isEmpty, "cli.doctor.vocabulary", [String(vocabularyKeys.count), String(missingVocabulary.count)])

        // 3. The prose template families are present.
        let diagnosticCount = table.keys.count(where: { $0.hasPrefix("diagnostic.") })
        let traceCount = table.keys.count(where: { $0.hasPrefix("trace.") })
        let validationCount = table.keys.count(where: { $0.hasPrefix("validation.") })
        report(
            diagnosticCount >= 20 && traceCount >= 10 && validationCount >= 21,
            "cli.doctor.templates",
            [String(diagnosticCount), String(traceCount), String(validationCount)],
        )

        // 4. End-to-end self test: a built-in fixture through the whole engine.
        let fixture = """
        template "com.example.doctor" {
            let Kind = "Xcode.IDEFoundation.TextSubstitutionFileTemplateKind"
            let Name = "Doctor Fixture"
            option "languageChoice" {
                let Identifier = "languageChoice"
                let Type = "popup"
                let Default = "Swift"
                let Values = ["Swift"]
                unit "Swift" {
                    node "___FILEBASENAME___.swift" {
                        let binary = false
                        let content = "struct ___FILEBASENAMEASIDENTIFIER___ {}\\n"
                    }
                }
            }
        }
        """
        do {
            let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("xctemplate-doctor-\(ProcessInfo.processInfo.processIdentifier)")
            defer { try? FileManager.default.removeItem(at: scratch) }
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
            let tokens = try Lexer(code: fixture).tokenize()
            var bundle = try Parser(tokens: tokens).parse()
            try Validator<XcodeTemplateBundle>.defaultTemplateValidator.validate(bundle)
            bundle.name = "Doctor Fixture.xctemplate"
            try PackManager.unpackBundle(bundle, toParentFolder: scratch.path)
            let repacked = try PackManager.packFolder(path: scratch.appendingPathComponent("Doctor Fixture.xctemplate").path)
            let reparsedSource = Decompiler.decompile(repacked)
            let (_, lexErrors) = Lexer(code: reparsedSource).tokenizeRecovering()
            let (reBundle, parseErrors) = Parser(tokens: Lexer(code: reparsedSource).tokenizeRecovering().tokens).parseRecovering()
            var produced = 0
            if lexErrors.isEmpty, parseErrors.isEmpty, let reBundle {
                let out = scratch.appendingPathComponent("expanded")
                try TemplateExpander.expand(reBundle, to: out.path, choices: [:])
                produced = (try? FileManager.default.contentsOfDirectory(atPath: out.path).count) ?? 0
            }
            report(lexErrors.isEmpty && parseErrors.isEmpty && produced > 0, "cli.doctor.selftest", [String(produced)])
        } catch {
            report(false, "cli.doctor.selftest_error", [error.localizedDescription])
        }

        if failures == 0 {
            print(Localization.render(key: "cli.doctor.result_ok", locale: locale) ?? "DOCTOR OK")
            exit(0)
        }
        print(Localization.render(key: "cli.doctor.result_fail", arguments: [String(failures)], locale: locale) ?? "DOCTOR FAIL (\(failures))")
        exit(1)
    }

    // `check <file.xctdsl>` is the front end of the checker (Dragon Book phases): the recovering lexer
    // collects every lexical error (panic-mode character deletion), the recovering parser collects every
    // syntax error (panic-mode resynchronization on the let/option/unit/node/directory/} tokens), and when
    // the syntax is clean the diagnostic validator runs the semantic checks on the parsed bundle. Errors are
    // reported as `file:line:column: error: message` (exit 1); a fully clean file prints OK (exit 0).
    // Semantic diagnostics are suppressed while syntax errors exist (a broken tree would only produce an
    // avalanche of spurious findings).
    if args.count >= 3, args[1] == "check" {
        let path = args[2]
        // The optional trailing locale renders diagnostic PROSE in that language; the `error:` and
        // `warning:` markers stay fixed deliberately (they are machine protocol, the compiler-output
        // convention editors parse, exactly as clang keeps them under any locale).
        let locale = args.count >= 4 ? args[3] : "en"
        do {
            let code = try String(contentsOfFile: path, encoding: .utf8)
            let (tokens, lexicalErrors) = Lexer(code: code).tokenizeRecovering()
            let (bundle, syntaxErrors) = Parser(tokens: tokens).parseRecovering()
            let allErrors = (lexicalErrors + syntaxErrors).sorted { ($0.line, $0.column) < ($1.line, $1.column) }
            for error in allErrors {
                print("\(path):\(error.line):\(error.column): error: \(error.localizedMessage(locale: locale))")
            }
            if allErrors.isEmpty, let bundle {
                // Structural rules first: what would make COMPILE throw is an error in the editor,
                // not a courtesy warning the user meets again later.
                var structuralErrors: [ValidationError] = []
                do {
                    try Validator<XcodeTemplateBundle>.defaultTemplateValidator.validate(bundle)
                } catch let findings as ValidationErrorCollection {
                    structuralErrors = findings.values
                }
                for finding in structuralErrors {
                    print("\(path): error: \(finding.localizedDescription(locale: locale))")
                }
                let validator = Validator<XcodeTemplateBundle>.diagnosticValidator
                do {
                    try validator.validate(bundle)
                    if !structuralErrors.isEmpty {
                        print("\(path): \(structuralErrors.count) semantic error(s)")
                        exit(1)
                    }
                } catch let findings as ValidationErrorCollection {
                    for finding in findings.values {
                        print("\(path): warning: \(finding.localizedDescription(locale: locale))")
                    }
                    for finding in bundle.caseCollisionFindings {
                        print("\(path): warning: \(finding.localizedText(locale: locale))")
                    }
                    for finding in bundle.optionCompletenessFindings {
                        print("\(path): warning: \(finding.localizedText(locale: locale))")
                    }
                    for finding in bundle.referentialIntegrityFindings {
                        print("\(path): warning: \(finding.localizedText(locale: locale))")
                    }
                    print("\(path): \(findings.values.count) semantic warning(s)")
                    exit(structuralErrors.isEmpty ? 0 : 1)
                }
                print("OK: \(path) is valid XCTemplateDSL (\(tokens.count) tokens)")
                exit(0)
            }
            if allErrors.isEmpty {
                print("OK: \(path) is valid XCTemplateDSL (\(tokens.count) tokens)")
                exit(0)
            }
            print("\(path): \(allErrors.count) error(s)")
            exit(1)
        } catch {
            print("\(path): error: \(error.localizedDescription)")
            exit(1)
        }
    }

    // `ast <file.xctdsl>` parses the DSL and prints the concrete syntax tree (kind, token span, source range)
    // as an indented outline, verifying the structural invariants an editor depends on: every child's span is
    // inside its parent's, siblings are ordered and non-overlapping, and the root spans every token. Exits 1
    // when an invariant fails.
    if args.count >= 3, args[1] == "ast" {
        let path = args[2]
        do {
            let code = try String(contentsOfFile: path, encoding: .utf8)
            let (tokens, _) = Lexer(code: code).tokenizeRecovering()
            let parser = Parser(tokens: tokens)
            let (_, syntaxErrors) = parser.parseRecovering()
            guard let tree = parser.syntaxTree else {
                print("\(path): no syntax tree (\(syntaxErrors.count) syntax error(s))")
                exit(1)
            }
            var nodeCount = 0
            var violations: [String] = []
            func verify(_ node: SyntaxNode, parentRange: Range<Int>?) {
                nodeCount += 1
                if let parentRange, !(parentRange.lowerBound <= node.tokenRange.lowerBound && node.tokenRange.upperBound <= parentRange.upperBound) {
                    violations.append("\(node.kind.rawValue) span \(node.tokenRange) escapes parent \(parentRange)")
                }
                var previousEnd = node.tokenRange.lowerBound
                for child in node.children {
                    if child.tokenRange.lowerBound < previousEnd {
                        violations.append("\(child.kind.rawValue) span \(child.tokenRange) overlaps its preceding sibling")
                    }
                    previousEnd = child.tokenRange.upperBound
                    verify(child, parentRange: node.tokenRange)
                }
            }
            verify(tree, parentRange: nil)
            if tree.tokenRange != 0 ..< tokens.count {
                violations.append("root spans \(tree.tokenRange), expected 0..<\(tokens.count)")
            }
            if violations.isEmpty {
                tree.walk { node, depth in
                    let indent = String(repeating: "  ", count: depth)
                    if let range = node.sourceRange(in: tokens) {
                        print("\(indent)\(node.kind.rawValue)  [\(range.startLine):\(range.startColumn) - \(range.endLine):\(range.endColumn)]")
                    } else {
                        print("\(indent)\(node.kind.rawValue)  [empty]")
                    }
                }
                print("AST OK: \(nodeCount) nodes, \(tokens.count) tokens" + (syntaxErrors.isEmpty ? "" : ", \(syntaxErrors.count) recovered syntax error(s)"))
                exit(0)
            }
            for violation in violations {
                print("\(path): AST INVARIANT: \(violation)")
            }
            exit(1)
        } catch {
            print("\(path): error: \(error.localizedDescription)")
            exit(1)
        }
    }

    // `doc <file.xctdsl> [locale]` emits every positioned help entry in the source: the hover stream an
    // IDE consumes. One line per entry: `line:col-line:col kind name | display | title`.
    if args.count >= 3, args[1] == "doc" {
        let path = args[2]
        let locale = args.count >= 4 ? args[3] : "en"
        do {
            let code = try String(contentsOfFile: path, encoding: .utf8)
            let entries = Documentation.Annotator.annotate(source: code, locale: locale)
            for positioned in entries {
                let e = positioned.entry
                print(
                    "\(positioned.startLine):\(positioned.startColumn)-\(positioned.endLine):\(positioned.endColumn) \(e.kind.rawValue) \(e.name) | \(e.displayName) | \(e.title)",
                )
            }
            print("DOC OK: \(entries.count) entr\(entries.count == 1 ? "y" : "ies")")
            exit(0)
        } catch {
            print("\(path): error: \(error.localizedDescription)")
            exit(1)
        }
    }

    // `hover <file.xctdsl> <line> <col> [locale]` answers the IDE's hover query at one position.
    if args.count >= 5, args[1] == "hover" {
        let path = args[2]
        let locale = args.count >= 6 ? args[5] : "en"
        do {
            let code = try String(contentsOfFile: path, encoding: .utf8)
            guard let line = Int(args[3]), let column = Int(args[4]) else {
                print("hover: line and column must be integers")
                exit(1)
            }
            if let hit = Documentation.Annotator.hover(source: code, line: line, column: column, locale: locale) {
                print("\(hit.entry.displayName) (\(hit.entry.kind.rawValue) \(hit.entry.name))")
                print(hit.entry.title)
                print(hit.entry.body)
                exit(0)
            }
            print("no documentation at \(line):\(column)")
            exit(0)
        } catch {
            print("\(path): error: \(error.localizedDescription)")
            exit(1)
        }
    }

    // `complete <file.xctdsl> <line> <col> [locale]` lists the completions the IDE can offer at a
    // position: construct keywords from the grammar's FIRST sets, key vocabulary after `let`, widget
    // values after `let Type =`, macros inside strings.
    if args.count >= 5, args[1] == "complete" {
        let path = args[2]
        let locale = args.count >= 6 ? args[5] : "en"
        do {
            let code = try String(contentsOfFile: path, encoding: .utf8)
            guard let line = Int(args[3]), let column = Int(args[4]) else {
                print("complete: line and column must be integers")
                exit(1)
            }
            let items = Documentation.Completer.complete(source: code, line: line, column: column, locale: locale)
            for item in items {
                print("\(item.kind.rawValue) \(item.insertText) | \(item.label) | \(item.detail)")
            }
            print("COMPLETE OK: \(items.count) item(s)")
            exit(0)
        } catch {
            print("\(path): error: \(error.localizedDescription)")
            exit(1)
        }
    }

    // `doccheck <file.xctdsl>` lists everything in the source the help catalog does NOT know (let keys
    // without an entry for their context, macros without an entry after family normalization). Empty
    // output and exit 0 = full coverage. The corpus doc gate runs this over every decompiled template.
    if args.count >= 3, args[1] == "doccheck" {
        let path = args[2]
        do {
            let code = try String(contentsOfFile: path, encoding: .utf8)
            let missing = Documentation.Annotator.undocumented(source: code)
            for name in missing {
                print("UNDOCUMENTED \(name)")
            }
            print(missing.isEmpty ? "DOCCHECK OK" : "DOCCHECK MISSING: \(missing.count)")
            exit(missing.isEmpty ? 0 : 1)
        } catch {
            print("\(path): error: \(error.localizedDescription)")
            exit(1)
        }
    }

    // `lint <xctemplate_dir>` runs the diagnostic validator and reports findings without rejecting (real Apple
    // templates can legitimately trip these, so they warn). It needs only the bundle path, so it is handled
    // before the compile/decompile argument guard.
    if args.count >= 3, args[1] == "lint" {
        let locale = args.count >= 4 ? args[3] : "en"
        do {
            let bundle = try PackManager.packFolder(path: args[2])
            let validator = Validator<XcodeTemplateBundle>.diagnosticValidator
            do {
                try validator.validate(bundle)
                print("OK: no diagnostics for \(args[2])")
            } catch let errors as ValidationErrorCollection {
                print("\(errors.values.count) diagnostic(s) for \(args[2]):")
                for error in errors.values {
                    print("  - \(error.localizedDescription(locale: locale))")
                }
                for group in bundle.pathCaseCollisions {
                    print("      " + BundleFinding(code: "case_collision_verbose", arguments: [group.joined(separator: "  vs  ")]).localizedText(locale: locale))
                }
                for finding in bundle.optionCompletenessFindings {
                    print("      \(finding.localizedText(locale: locale))")
                }
                for finding in bundle.referentialIntegrityFindings {
                    print("      \(finding.localizedText(locale: locale))")
                }
            }
            exit(0)
        } catch {
            print("Lint failed: \(error.localizedDescription)")
            exit(1)
        }
    }

    // `locales` lists every language present in the engine's String Catalog.
    if args.count >= 2, args[1] == "locales" {
        for locale in Localization.Strings.availableLocales() {
            print(locale)
        }
        exit(0)
    }

    // `explain <name> [locale]` answers "what is this?" for any vocabulary name WITHOUT a source file:
    // a macro spelling, a manifest/option/definition key, a construct keyword, or an option Type value.
    if args.count >= 3, args[1] == "explain" {
        let name = args[2]
        let locale = args.count >= 4 ? args[3] : "en"
        var entry: Documentation.Entry?
        if name.hasPrefix("___") {
            entry = Documentation.Catalog.lookup(macro: name, locale: locale)
        }
        if entry == nil { entry = Documentation.Catalog.lookup(keyword: name, locale: locale) }
        if entry == nil { entry = Documentation.Catalog.lookup(letKey: name, context: .template, locale: locale) }
        if entry == nil { entry = Documentation.Catalog.lookup(letKey: name, context: .option, locale: locale) }
        if entry == nil { entry = Documentation.Catalog.lookup(letKey: name, context: .node, locale: locale) }
        if entry == nil { entry = Documentation.Catalog.lookup(optionTypeValue: name, locale: locale) }
        if let entry {
            print("\(entry.displayName) (\(entry.kind.rawValue) \(entry.name))")
            print(entry.title)
            print(entry.body)
            exit(0)
        }
        print("unknown name: \(name)")
        exit(1)
    }

    // `options <file.xctdsl>` prints the template's USER INTERACTION POINTS as data: every control the
    // options form would present (identifier, widget, label, default, values) plus the reserved keys.
    // This is exactly what `expand`'s key=value arguments can inject.
    if args.count >= 3, args[1] == "options" {
        let path = args[2]
        do {
            let code = try String(contentsOfFile: path, encoding: .utf8)
            let tokens = try Lexer(code: code).tokenize()
            let bundle = try Parser(tokens: tokens).parse()
            var presented = 0
            if case let .array(options)? = bundle.metadata["Options"] {
                for optionValue in options {
                    guard case let .dictionary(opt) = optionValue,
                          let identifier = opt["Identifier"]?.stringValue else { continue }
                    presented += 1
                    let type = opt["Type"]?.stringValue ?? "text"
                    let label = opt["Name"]?.stringValue ?? ""
                    let dflt = opt["Default"]?.stringValue ?? ""
                    let values = opt["Values"]?.arrayValue?.compactMap(\.stringValue) ?? []
                    var line = "option \(identifier) type=\(type)"
                    if !label.isEmpty { line += " name=\"\(label)\"" }
                    if !dflt.isEmpty { line += " default=\"\(dflt)\"" }
                    if !values.isEmpty { line += " values=[" + values.joined(separator: ", ") + "]" }
                    print(line)
                }
            }
            print("reserved productName|packageName (the save sheet's name; feeds ___PACKAGENAME___ and kin)")
            print("reserved fileBasename (the file flow's Save As; feeds ___FILEBASENAME___ and kin)")
            print("reserved organizationName projectName (identity fields)")
            print("OPTIONS OK: \(presented) presented option(s)")
            exit(0)
        } catch let error as SyntaxError {
            print("\(path):\(error.line):\(error.column): error: \(error.message)")
            exit(1)
        } catch {
            print("\(path): error: \(error.localizedDescription)")
            exit(1)
        }
    }

    if args.count < 4 {
        printUsage()
        exit(1)
    }

    let command = args[1]
    let srcPath = args[2]
    let destPath = args[3]

    do {
        if command == "compile" {
            let dslCode = try String(contentsOfFile: srcPath, encoding: .utf8)
            let lexer = Lexer(code: dslCode)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens: tokens)
            var bundle = try parser.parse()

            // Run validation
            let validator = Validator<XcodeTemplateBundle>.defaultTemplateValidator
            try validator.validate(bundle)

            // Ensure folder name is defined
            var folderName = bundle.identifier
            if folderName.isEmpty {
                let fileURL = URL(fileURLWithPath: srcPath)
                folderName = fileURL.deletingPathExtension().lastPathComponent
            }
            if case let .string(name) = bundle.metadata["Name"] {
                folderName = name.replacingOccurrences(of: "/", with: " and ")
            }
            if !folderName.hasSuffix(".xctemplate") {
                folderName += ".xctemplate"
            }
            bundle.name = folderName

            try PackManager.unpackBundle(bundle, toParentFolder: destPath)
            print("Successfully compiled DSL \(srcPath) into parent folder \(destPath)")

        } else if command == "decompile" {
            let bundle = try PackManager.packFolder(path: srcPath)

            // Run validation
            let validator = Validator<XcodeTemplateBundle>.defaultTemplateValidator
            try validator.validate(bundle)

            let dslCode = Decompiler.decompile(bundle)
            try dslCode.write(toFile: destPath, atomically: true, encoding: .utf8)
            print("Successfully decompiled template \(srcPath) -> DSL \(destPath)")
        } else if command == "expand" {
            let dslCode = try String(contentsOfFile: srcPath, encoding: .utf8)
            let lexer = Lexer(code: dslCode)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens: tokens)
            let bundle = try parser.parse()

            // Run validation
            let validator = Validator<XcodeTemplateBundle>.defaultTemplateValidator
            try validator.validate(bundle)

            var choices: [String: String] = [:]
            var traceEnabled = false
            var traceLocale = "en"
            if args.count > 4 {
                for i in 4 ..< args.count {
                    if args[i] == "--trace" { traceEnabled = true
                        continue
                    }
                    if args[i].hasPrefix("--locale=") { traceLocale = String(args[i].dropFirst("--locale=".count))
                        continue
                    }
                    let parts = args[i].components(separatedBy: "=")
                    if parts.count == 2 {
                        choices[parts[0]] = parts[1]
                    }
                }
            }

            let trace: ((TraceLine) -> Void)? = traceEnabled ? { print("trace: \($0.localizedText(locale: traceLocale))") } : nil
            try TemplateExpander.expand(bundle, to: destPath, choices: choices, trace: trace)
            print("Successfully expanded template DSL \(srcPath) into \(destPath)")
        } else {
            print("Unknown command: \(command)")
            exit(1)
        }
    } catch let error as ExpanderError {
        // Typed engine errors describe themselves; the NSError bridge would hide the description.
        print("Operation failed: \(error)")
        exit(1)
    } catch let error as SyntaxError {
        print("Operation failed: \(error)")
        exit(1)
    } catch {
        print("Operation failed: \(error.localizedDescription)")
        exit(1)
    }
#else
    print("xctemplate is not supported on WebAssembly.")
#endif
