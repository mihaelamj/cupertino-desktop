import Foundation
import SharedModels

#if !os(WASI)
    public class TemplateExpander {
        /// Expand a template bundle into `destPath`, applying the user's option `choices` (defaults where no
        /// choice is given). The optional `trace` sink receives one line per decision the expander makes:
        /// which value each option resolved to (and why), which units a value activated, how each node
        /// resolved to a physical file, and which macros were replaced where. This is the template debugger's
        /// backend: the IDE renders the trace as a step-through of the instantiation.
        ///
        /// USER INTERACTION POINT (the whole surface). `choices` is the programmatic stand-in for every
        /// moment real Xcode stops and waits for the user during New Project / New File:
        ///
        ///   1. The chooser sheet commits NO values; it only picks which bundle this function receives.
        ///   2. The options form ("Choose options for your new project/file") is one `choices` entry per
        ///      presented option, keyed by the option's `Identifier`. Each control on that form is one
        ///      `Options` array entry: `Type` is the widget, `Name` the label, `Values` the menu rows,
        ///      `Default` the preselection. Step 1 below is the form's commit.
        ///   3. The save sheet (name + location) is the reserved keys `productName`/`packageName` and
        ///      `fileBasename`; they exist outside the `Options` array and feed macros only (step 3).
        ///
        /// An empty `choices` means "the user clicked Next through every sheet": pure defaults. That is
        /// how the whole-corpus expand gate exercises all 10,117 templates. Evidence of the real dialogs:
        /// `templatomat/docs/analysis/cross-version/dialog-screenshot-clusters.md`.
        public static func expand(
            _ bundle: XcodeTemplateBundle,
            to destPath: String,
            choices: [String: String],
            trace: ((TraceLine) -> Void)? = nil,
        ) throws {
            let fileManager = FileManager.default
            let destURL = URL(fileURLWithPath: destPath)
            try fileManager.createDirectory(at: destURL, withIntermediateDirectories: true, attributes: nil)

            // 1. Gather option values (either from user choice or defaults).
            // USER INTERACTION POINT: this loop IS the options form. In real Xcode each `Options` entry
            // renders as one control and the sheet blocks until Next; here the same decision is the
            // `choices[optId]` lookup, `Default` standing in for an untouched control. Templates with an
            // empty `Options` array present no options sheet at all (chooser straight to save sheet).
            var activeOptions: [String: String] = [:]
            var optionMap: [String: PropertyListValue] = [:]

            if case let .array(options) = bundle.metadata["Options"] {
                for optVal in options {
                    guard case let .dictionary(opt) = optVal,
                          case let .string(optId) = opt["Identifier"] else { continue }
                    optionMap[optId] = .dictionary(opt)

                    // Get default
                    var val = ""
                    var origin = "default"
                    if case let .string(def) = opt["Default"] {
                        val = def
                    }
                    // Override with user choices
                    if let choice = choices[optId] {
                        val = choice
                        origin = "user choice"
                    }
                    activeOptions[optId] = val
                    trace?(TraceLine(code: origin == "default" ? "option_resolved_default" : "option_resolved_choice", arguments: [optId, val]))
                }
            }

            // 2. Gather active units and merge metadata/definitions
            var activeNodes: Set<String> = []

            // Root nodes
            if case let .array(rootNodes) = bundle.metadata["Nodes"] {
                for nodeVal in rootNodes {
                    if case let .string(path) = nodeVal {
                        activeNodes.insert(path)
                    }
                }
            }

            // Root Definitions
            var resolvedDefs: [String: PropertyListValue] = [:]
            if case let .dictionary(rootDefs) = bundle.metadata["Definitions"] {
                resolvedDefs = rootDefs
            }

            // Process active options & their corresponding units.
            // The STRUCTURAL consequence of the options form: a value chosen on the sheet selects a
            // `Units` entry, which adds nodes and merges definitions (which files exist and with what
            // content). The TEXTUAL consequence happens later, in the macro environment of step 3.
            for (optId, val) in activeOptions {
                guard let optVal = optionMap[optId],
                      case let .dictionary(opt) = optVal else { continue }

                if case let .dictionary(units) = opt["Units"],
                   let unitVal = units[val]
                {
                    let unitMetadataList: [[String: PropertyListValue]]
                    if case let .dictionary(dict) = unitVal {
                        unitMetadataList = [dict]
                    } else if case let .array(arr) = unitVal {
                        unitMetadataList = arr.compactMap { item -> [String: PropertyListValue]? in
                            if case let .dictionary(d) = item { return d }
                            return nil
                        }
                    } else {
                        continue
                    }
                    trace?(TraceLine(code: "unit_activated", arguments: [optId, val, String(unitMetadataList.count)]))

                    for unitMetadata in unitMetadataList {
                        // Add unit nodes
                        if case let .array(unitNodes) = unitMetadata["Nodes"] {
                            for nodeVal in unitNodes {
                                if case let .string(path) = nodeVal {
                                    activeNodes.insert(path)
                                    trace?(TraceLine(code: "unit_adds_node", arguments: [path]))
                                }
                            }
                        }

                        // Merge unit definitions
                        if case let .dictionary(unitDefs) = unitMetadata["Definitions"] {
                            for (k, v) in unitDefs {
                                if case let .dictionary(newDef) = v {
                                    if case var .dictionary(existingDef) = resolvedDefs[k] {
                                        for (subK, subV) in newDef {
                                            existingDef[subK] = subV
                                        }
                                        resolvedDefs[k] = .dictionary(existingDef)
                                    } else {
                                        resolvedDefs[k] = v
                                    }
                                } else {
                                    resolvedDefs[k] = v
                                }
                            }
                        }
                    }
                }
            }

            if activeNodes.isEmpty {
                for path in bundle.files.keys {
                    activeNodes.insert(path)
                }
                for path in resolvedDefs.keys {
                    activeNodes.insert(path)
                }
            }

            // 3. Resolve macro mappings (default values for common macros if not provided).
            // USER INTERACTION POINT: the save sheet and identity fields. `productName`/`packageName`
            // and `fileBasename` are what the user types into "Save As:" / "Product Name"; they are NOT
            // `Options` entries, which is why they are read from reserved keys here rather than resolved
            // in step 1. Every other choice key also becomes a `___KEY___` macro, so an IDE can inject
            // custom values exactly as if a control for them had existed on the form.
            var macroReplacements: [String: String] = [:]
            let prodName = choices["packageName"] ?? choices["productName"] ?? "MyProduct"
            macroReplacements["___PACKAGENAME___"] = prodName
            macroReplacements["___PROJECTNAME___"] = choices["projectName"] ?? prodName
            let fileBase = choices["fileBasename"] ?? "MyFile"
            macroReplacements["___FILEBASENAME___"] = fileBase
            macroReplacements["___FILEBASENAMEASIDENTIFIER___"] = fileBase.replacingOccurrences(of: " ", with: "_")
            macroReplacements["___ORGANIZATIONNAME___"] = choices["organizationName"] ?? "MyCompany"

            // Pinned locale and calendar: with the device defaults, a non-Gregorian system calendar would
            // expand ___YEAR___ to e.g. 2569 (Buddhist era). The user's time zone is intentional (the date is
            // the user's local date); the calendar and digits are not negotiable.
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.dateFormat = "yyyy-MM-dd"
            macroReplacements["___DATE___"] = formatter.string(from: Date())
            formatter.dateFormat = "yyyy"
            macroReplacements["___YEAR___"] = formatter.string(from: Date())

            // User custom macros from arguments
            for (k, v) in choices {
                macroReplacements["___\(k)___"] = v
            }

            // Replacement order is longest macro first and then alphabetical: maximal munch (Dragon Book
            // section 3.1, the longest-match rule), so a macro that is a prefix-overlap of another can never
            // corrupt it, and the dictionary's randomized iteration order cannot make expansion
            // nondeterministic between runs.
            let orderedMacros = macroReplacements.sorted { lhs, rhs in
                lhs.key.count != rhs.key.count ? lhs.key.count > rhs.key.count : lhs.key < rhs.key
            }
            // The macro-replacement context is TYPED: path replacement vs content replacement are two
            // distinct trace codes, so no English fragment ("path", "content of ...") rides in the data.
            enum MacroContext {
                case path
                case content(String)
            }
            func replaceMacros(in string: String, context: MacroContext? = nil) -> String {
                var result = string
                for (macro, replacement) in orderedMacros {
                    if let context, result.contains(macro) {
                        switch context {
                        case .path:
                            trace?(TraceLine(code: "macro_replaced_path", arguments: [macro, replacement]))
                        case let .content(file):
                            trace?(TraceLine(code: "macro_replaced_content", arguments: [file, macro, replacement]))
                        }
                    }
                    result = result.replacingOccurrences(of: macro, with: replacement)
                }
                return result
            }

            // 4. Generate files
            for nodePath in activeNodes {
                // Find resolved definition
                var physicalPath = nodePath
                var fileContent: String? = nil
                var isBinary = false

                if let defVal = resolvedDefs[nodePath] {
                    if case let .string(inlineStr) = defVal {
                        fileContent = inlineStr
                    } else if case let .dictionary(defDict) = defVal {
                        if case let .string(p) = defDict["Path"] {
                            physicalPath = p
                        }
                        if case let .boolean(b) = defDict["binary"] {
                            isBinary = b
                        }
                        if case let .string(c) = defDict["content"] {
                            fileContent = c
                        }
                    }
                }

                // If fileContent was not defined inline, get it from bundle files
                if fileContent == nil {
                    if let fileInfo = bundle.files[physicalPath] {
                        fileContent = fileInfo.content
                        isBinary = (fileInfo.type == "binary")
                    }
                }

                guard let content = fileContent else {
                    // The trace line is the only report: a library must not write to stdout, and an
                    // unresolved node is legitimate (insertion slot or ancestor-provided content).
                    trace?(TraceLine(code: "node_unresolved", arguments: [nodePath, physicalPath]))
                    continue
                }

                trace?(TraceLine(code: isBinary ? "node_resolved_binary" : "node_resolved", arguments: [nodePath, physicalPath]))
                // Replace macros in physical path and content (if text)
                let finalRelPath = replaceMacros(in: physicalPath, context: .path)
                let fileURL = destURL.appendingPathComponent(finalRelPath)
                // Confinement: the resolved path must stay under the output directory. A `..` segment
                // or an absolute value can arrive through a node path or a user-supplied choice (the
                // name field feeds ___FILEBASENAME___ straight into paths); refuse instead of writing
                // wherever the buffer says.
                let confinedRoot = destURL.standardizedFileURL.path + "/"
                guard fileURL.standardizedFileURL.path.hasPrefix(confinedRoot) else {
                    throw ExpanderError.pathOutsideOutput(path: finalRelPath)
                }
                try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)

                if isBinary {
                    if let data = Data(base64Encoded: content) {
                        try data.write(to: fileURL)
                    } else {
                        throw ExpanderError.undecodableBinaryContent(path: finalRelPath)
                    }
                } else {
                    let finalContent = replaceMacros(in: content, context: .content(finalRelPath))
                    try finalContent.write(to: fileURL, atomically: true, encoding: .utf8)
                }
                trace?(TraceLine(code: "file_written", arguments: [finalRelPath]))
            }
        }
    }
#endif
