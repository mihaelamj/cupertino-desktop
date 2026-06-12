import Foundation
import SharedModels

#if !os(WASI)
    public class Decompiler {
        public static func isValidIdentifier(_ s: String) -> Bool {
            if s.isEmpty { return false }
            let first = s.first!
            guard first.isLetter || first == "_" else { return false }
            return s.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
        }

        public static func formatValue(_ val: PropertyListValue) -> String {
            switch val {
            case let .boolean(b):
                return b ? "true" : "false"
            case let .integer(i):
                return "\(i)"
            case let .real(d):
                // Swift's default description is the shortest string that round-trips the exact Double.
                return "\(d)"
            case let .string(s):
                if s.contains("\n") {
                    var hashCount = 1
                    while s.contains("\"\"\"" + String(repeating: "#", count: hashCount)) {
                        hashCount += 1
                    }
                    let hashes = String(repeating: "#", count: hashCount)
                    return "\(hashes)\"\"\"\n\(s)\n\"\"\"\(hashes)"
                } else if s.contains("\"") || s.contains("\\") {
                    var hashCount = 1
                    while s.contains("\"" + String(repeating: "#", count: hashCount)) {
                        hashCount += 1
                    }
                    let hashes = String(repeating: "#", count: hashCount)
                    return "\(hashes)\"\(s)\"\(hashes)"
                } else {
                    return "\"\(s)\""
                }
            case let .array(arr):
                let items = arr.map { formatValue($0) }.joined(separator: ", ")
                return "[\(items)]"
            case let .dictionary(dict):
                let items = dict.sorted(by: { $0.key < $1.key }).map { k, v -> String in
                    let keyStr = isValidIdentifier(k) ? k : "\"\(k.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
                    return "\(keyStr): \(formatValue(v))"
                }.joined(separator: ", ")
                return "{ \(items) }"
            }
        }

        public static func formatProperty(_ key: String, _ val: PropertyListValue, indent: Int) -> String {
            let ind = String(repeating: "    ", count: indent)
            let keyStr = isValidIdentifier(key) ? key : "\"\(key.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
            switch val {
            case let .boolean(b):
                return "\(ind)let \(keyStr) = \(b ? "true" : "false")"
            case let .integer(i):
                return "\(ind)let \(keyStr) = \(i)"
            case let .real(d):
                return "\(ind)let \(keyStr) = \(d)"
            case let .string(s):
                if s.contains("\n") {
                    var hashCount = 1
                    while s.contains("\"\"\"" + String(repeating: "#", count: hashCount)) {
                        hashCount += 1
                    }
                    let hashes = String(repeating: "#", count: hashCount)
                    return "\(ind)let \(keyStr) = \(hashes)\"\"\"\n\(s)\n\"\"\"\(hashes)"
                } else if s.contains("\"") || s.contains("\\") {
                    var hashCount = 1
                    while s.contains("\"" + String(repeating: "#", count: hashCount)) {
                        hashCount += 1
                    }
                    let hashes = String(repeating: "#", count: hashCount)
                    return "\(ind)let \(keyStr) = \(hashes)\"\(s)\"\(hashes)"
                } else {
                    return "\(ind)let \(keyStr) = \"\(s)\""
                }
            case let .array(arr):
                let items = arr.map { formatValue($0) }.joined(separator: ", ")
                return "\(ind)let \(keyStr) = [\(items)]"
            case let .dictionary(dict):
                let items = dict.sorted(by: { $0.key < $1.key }).map { k, v -> String in
                    let subKeyStr = isValidIdentifier(k) ? k : "\"\(k.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
                    return "\(subKeyStr): \(formatValue(v))"
                }.joined(separator: ", ")
                return "\(ind)let \(keyStr) = { \(items) }"
            }
        }

        public static func getPhysicalPath(forNode nodePath: String, inDefinitions definitionsVal: PropertyListValue?) -> String {
            if let definitionsVal,
               case let .dictionary(defs) = definitionsVal,
               case let .dictionary(nodeDef) = defs[nodePath],
               case let .string(p) = nodeDef["Path"]
            {
                return p
            }
            return nodePath
        }

        public static func isPathProcessed(_ path: String, processed: Set<String>) -> Bool {
            processed.contains(path)
        }

        public static func decompile(_ bundle: XcodeTemplateBundle) -> String {
            var lines: [String] = []
            lines.append("template \"\(bundle.identifier)\" {")

            // Root metadata properties
            for (k, v) in bundle.metadata.sorted(by: { $0.key < $1.key }) {
                if k == "Identifier" { continue }
                if k == "Definitions" {
                    if case let .dictionary(defs) = v, defs.isEmpty {
                        lines.append(formatProperty(k, v, indent: 1))
                    }
                    continue
                }
                if k == "Options" {
                    if case let .array(arr) = v, arr.isEmpty {
                        lines.append(formatProperty(k, v, indent: 1))
                    }
                    continue
                }
                lines.append(formatProperty(k, v, indent: 1))
            }

            var processedFiles: Set<String> = []
            var processedDefinitions: Set<String> = []

            // Explicit nodes
            if case let .array(nodes) = bundle.metadata["Nodes"] {
                for nodeVal in nodes {
                    guard case let .string(nodePath) = nodeVal else { continue }
                    processedDefinitions.insert(nodePath)
                    lines.append("    node \"\(nodePath)\" {")

                    // Get definitions
                    let defsVal = bundle.metadata["Definitions"]

                    // Definitions properties
                    if case let .dictionary(defs) = defsVal,
                       let defNodeVal = defs[nodePath]
                    {
                        if case let .string(s) = defNodeVal {
                            lines.append("        let _isString = true")
                            lines.append(formatProperty("content", .string(s), indent: 2))
                        } else if case let .dictionary(nodeDefs) = defNodeVal {
                            for (k, v) in nodeDefs.sorted(by: { $0.key < $1.key }) {
                                lines.append(formatProperty(k, v, indent: 2))
                            }
                        }
                    }

                    // Resolve physical path to check for content
                    let physicalPath = getPhysicalPath(forNode: nodePath, inDefinitions: defsVal)
                    processedFiles.insert(physicalPath)
                    if let fileInfo = bundle.files[physicalPath] {
                        lines.append(formatProperty("binary", .boolean(fileInfo.type == "binary"), indent: 2))
                        lines.append(formatProperty("content", .string(fileInfo.content), indent: 2))
                    }
                    lines.append("    }")
                }
            }

            // Options array
            if case let .array(options) = bundle.metadata["Options"] {
                for optVal in options {
                    guard case let .dictionary(opt) = optVal,
                          case let .string(optId) = opt["Identifier"] else { continue }

                    lines.append("    option \"\(optId)\" {")
                    for (k, v) in opt.sorted(by: { $0.key < $1.key }) {
                        if k == "Identifier" { continue }
                        if k == "Units" {
                            if case let .dictionary(units) = v, units.isEmpty {
                                lines.append(formatProperty(k, v, indent: 2))
                            }
                            continue
                        }
                        lines.append(formatProperty(k, v, indent: 2))
                    }

                    // Units map
                    if case let .dictionary(units) = opt["Units"] {
                        for (unitVal, unitDataVal) in units.sorted(by: { $0.key < $1.key }) {
                            if case let .array(arr) = unitDataVal, arr.isEmpty {
                                lines.append("        unit \"\(unitVal)\" {")
                                lines.append("            let _isEmptyArray = true")
                                lines.append("        }")
                                continue
                            }
                            if case let .dictionary(dict) = unitDataVal, dict.isEmpty {
                                lines.append("        unit \"\(unitVal)\" {")
                                lines.append("        }")
                                continue
                            }

                            let isArray: Bool
                            let unitList: [[String: PropertyListValue]]
                            if case let .dictionary(dict) = unitDataVal {
                                unitList = [dict]
                                isArray = false
                            } else if case let .array(arr) = unitDataVal {
                                unitList = arr.compactMap { val -> [String: PropertyListValue]? in
                                    if case let .dictionary(d) = val { return d }
                                    return nil
                                }
                                isArray = true
                            } else {
                                continue
                            }

                            for unitData in unitList {
                                lines.append("        unit \"\(unitVal)\" {")
                                if isArray {
                                    lines.append("            let _isArray = true")
                                }

                                // Unit metadata
                                for (k, v) in unitData.sorted(by: { $0.key < $1.key }) {
                                    if k == "Definitions" {
                                        if case let .dictionary(defs) = v, defs.isEmpty {
                                            lines.append(formatProperty(k, v, indent: 3))
                                        }
                                        continue
                                    }
                                    lines.append(formatProperty(k, v, indent: 3))
                                }

                                var processedUnitDefinitions: Set<String> = []

                                // Unit nodes
                                if case let .array(unitNodes) = unitData["Nodes"] {
                                    for unodeVal in unitNodes {
                                        guard case let .string(unodePath) = unodeVal else { continue }
                                        processedUnitDefinitions.insert(unodePath)
                                        lines.append("            node \"\(unodePath)\" {")

                                        let udefsVal = unitData["Definitions"]
                                        if case let .dictionary(udefs) = udefsVal,
                                           let unodeDefsVal = udefs[unodePath]
                                        {
                                            if case let .string(s) = unodeDefsVal {
                                                lines.append("                let _isString = true")
                                                lines.append(formatProperty("content", .string(s), indent: 4))
                                            } else if case let .dictionary(unodeDefs) = unodeDefsVal {
                                                for (k, v) in unodeDefs.sorted(by: { $0.key < $1.key }) {
                                                    lines.append(formatProperty(k, v, indent: 4))
                                                }
                                            }
                                        }

                                        // Resolve physical path to check for content
                                        var physicalPath = getPhysicalPath(forNode: unodePath, inDefinitions: udefsVal)
                                        if physicalPath == unodePath {
                                            // Fallback to root definitions
                                            physicalPath = getPhysicalPath(forNode: unodePath, inDefinitions: bundle.metadata["Definitions"])
                                        }

                                        processedFiles.insert(physicalPath)
                                        if let fileInfo = bundle.files[physicalPath] {
                                            lines.append(formatProperty("binary", .boolean(fileInfo.type == "binary"), indent: 4))
                                            lines.append(formatProperty("content", .string(fileInfo.content), indent: 4))
                                        }
                                        lines.append("            }")
                                    }
                                }

                                // Remaining unit definitions
                                if case let .dictionary(udefs) = unitData["Definitions"] {
                                    for (unodePath, unodeDefsVal) in udefs.sorted(by: { $0.key < $1.key }) {
                                        if processedUnitDefinitions.contains(unodePath) { continue }
                                        processedUnitDefinitions.insert(unodePath)

                                        lines.append("            node \"\(unodePath)\" {")
                                        if case let .string(s) = unodeDefsVal {
                                            lines.append("                let _isString = true")
                                            lines.append(formatProperty("content", .string(s), indent: 4))
                                        } else if case let .dictionary(unodeDefs) = unodeDefsVal {
                                            for (k, v) in unodeDefs.sorted(by: { $0.key < $1.key }) {
                                                lines.append(formatProperty(k, v, indent: 4))
                                            }
                                        }

                                        // Resolve physical path to check for content
                                        var physicalPath = getPhysicalPath(forNode: unodePath, inDefinitions: unitData["Definitions"])
                                        if physicalPath == unodePath {
                                            physicalPath = getPhysicalPath(forNode: unodePath, inDefinitions: bundle.metadata["Definitions"])
                                        }

                                        processedFiles.insert(physicalPath)
                                        if let fileInfo = bundle.files[physicalPath] {
                                            lines.append(formatProperty("binary", .boolean(fileInfo.type == "binary"), indent: 4))
                                            lines.append(formatProperty("content", .string(fileInfo.content), indent: 4))
                                        }
                                        lines.append("            }")
                                    }
                                }
                                lines.append("        }")
                            }
                        }
                    }
                    lines.append("    }")
                }
            }

            // Remaining root definitions
            if case let .dictionary(defs) = bundle.metadata["Definitions"] {
                let defsVal = bundle.metadata["Definitions"]
                for (nodePath, defNodeVal) in defs.sorted(by: { $0.key < $1.key }) {
                    if processedDefinitions.contains(nodePath) { continue }
                    processedDefinitions.insert(nodePath)

                    lines.append("    node \"\(nodePath)\" {")
                    if case let .string(s) = defNodeVal {
                        lines.append("        let _isString = true")
                        lines.append(formatProperty("content", .string(s), indent: 2))
                    } else if case let .dictionary(nodeDefs) = defNodeVal {
                        for (k, v) in nodeDefs.sorted(by: { $0.key < $1.key }) {
                            lines.append(formatProperty(k, v, indent: 2))
                        }
                    }

                    // Resolve physical path to check for content
                    let physicalPath = getPhysicalPath(forNode: nodePath, inDefinitions: defsVal)
                    processedFiles.insert(physicalPath)
                    if let fileInfo = bundle.files[physicalPath] {
                        lines.append(formatProperty("binary", .boolean(fileInfo.type == "binary"), indent: 2))
                        lines.append(formatProperty("content", .string(fileInfo.content), indent: 2))
                    }
                    lines.append("    }")
                }
            }

            // Remaining files at root level
            for (relPath, fileInfo) in bundle.files.sorted(by: { $0.key < $1.key }) {
                if isPathProcessed(relPath, processed: processedFiles) { continue }
                lines.append("    node \"\(relPath)\" {")

                if case let .dictionary(defs) = bundle.metadata["Definitions"],
                   let nodeDefsVal = defs[relPath]
                {
                    if case let .string(s) = nodeDefsVal {
                        lines.append("        let _isString = true")
                        lines.append(formatProperty("content", .string(s), indent: 2))
                    } else if case let .dictionary(nodeDefs) = nodeDefsVal {
                        for (k, v) in nodeDefs.sorted(by: { $0.key < $1.key }) {
                            lines.append(formatProperty(k, v, indent: 2))
                        }
                    }
                }

                lines.append(formatProperty("binary", .boolean(fileInfo.type == "binary"), indent: 2))
                lines.append(formatProperty("content", .string(fileInfo.content), indent: 2))
                lines.append("    }")
            }

            // Empty directories (no files to imply them), so the folder structure round-trips exactly.
            for dir in bundle.emptyDirectories.sorted() {
                lines.append("    directory \"\(dir)\"")
            }

            lines.append("}")
            return lines.joined(separator: "\n")
        }
    }
#endif
