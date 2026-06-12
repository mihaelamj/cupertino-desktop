import Foundation
import Lexer
import Parser

public extension Documentation {
    /// Walks a source and attaches catalog knowledge to positions: the hover stream. Recovery
    /// tolerant by construction (recovering lexer and parser), so a broken source still documents
    /// everything it can; hover help never disappears because of an error elsewhere.
    enum Annotator {
        /// Every positioned help entry in the source, in source order. `locale` picks the language
        /// of the help text (resource-driven; `en` is the reference table).
        public static func annotate(source: String, locale: String = "en") -> [PositionedEntry] {
            let (tokens, _) = Lexer(code: source).tokenizeRecovering()
            let parser = Parser(tokens: tokens)
            _ = parser.parseRecovering()
            let contexts = contextKinds(tokens: tokens, tree: parser.syntaxTree)
            let constructStarts = keywordPositions(tree: parser.syntaxTree)
            var entries: [PositionedEntry] = []

            var index = 0
            while index < tokens.count {
                let token = tokens[index]
                switch token.type {
                case .letKeyword:
                    if let entry = Catalog.lookup(keyword: "let", locale: locale) {
                        entries.append(positioned(entry, at: token))
                    }
                    // The key token follows; documented against the construct it sits in.
                    if index + 1 < tokens.count {
                        let keyToken = tokens[index + 1]
                        let key = keyToken.value
                        if let entry = Catalog.lookup(letKey: key, context: contexts[index + 1], locale: locale) {
                            entries.append(positioned(entry, at: keyToken))
                        }
                        // Special case: the value of `let Type = "..."` inside an option block is
                        // itself vocabulary (which widget the options form draws).
                        if key == "Type", contexts[index + 1] == .option,
                           index + 3 < tokens.count, tokens[index + 2].type == .equals,
                           tokens[index + 3].type == .string,
                           let entry = Catalog.lookup(optionTypeValue: tokens[index + 3].value, locale: locale)
                        {
                            entries.append(positioned(entry, at: tokens[index + 3]))
                        }
                    }
                case .identifier:
                    // A construct keyword is an IDENT at a construct's first token (unreserved
                    // keywords disambiguate by position, the grammar's discipline).
                    if constructStarts[index] == token.value, let entry = Catalog.lookup(keyword: token.value, locale: locale) {
                        entries.append(positioned(entry, at: token))
                    }
                case .string, .multilineString:
                    // Sub-ranges are EXACT where provable: when the cooked prefix before a
                    // macro contains no character an escape sequence can produce, raw and
                    // cooked offsets agree, and the entry hugs the spelling. Otherwise the
                    // entry spans the whole string token: true exactness behind an escape
                    // needs the cooked-to-source offset map, the trivia-preservation work.
                    for macro in macros(in: token.value) {
                        guard let entry = Catalog.lookup(macro: macro, locale: locale) else { continue }
                        if token.type == .string,
                           token.line == token.endLine,
                           let range = token.value.range(of: macro),
                           token.value[..<range.lowerBound].allSatisfy({ !"\n\t\"\\".contains($0) })
                        {
                            let prefix = token.value.distance(from: token.value.startIndex, to: range.lowerBound)
                            let start = token.column + 1 + prefix
                            entries.append(PositionedEntry(
                                startLine: token.line,
                                startColumn: start,
                                endLine: token.line,
                                endColumn: start + macro.count,
                                entry: entry,
                            ))
                        } else {
                            entries.append(positioned(entry, at: token))
                        }
                    }
                default:
                    break
                }
                index += 1
            }
            return entries
        }

        /// Everything in the source the catalog does NOT know: `let` keys with no entry for their
        /// context and macros with no entry after family normalization. The corpus doc gate runs
        /// this over all 10,117 decompiled templates and demands emptiness: "every little possible
        /// thing" has help, proven, not assumed.
        public static func undocumented(source: String) -> [String] {
            let (tokens, _) = Lexer(code: source).tokenizeRecovering()
            let parser = Parser(tokens: tokens)
            _ = parser.parseRecovering()
            let contexts = contextKinds(tokens: tokens, tree: parser.syntaxTree)
            var missing: Set<String> = []

            var index = 0
            while index < tokens.count {
                let token = tokens[index]
                switch token.type {
                case .letKeyword:
                    if index + 1 < tokens.count {
                        let key = tokens[index + 1].value
                        if Catalog.lookup(letKey: key, context: contexts[index + 1]) == nil {
                            missing.insert("key:\(key)")
                        }
                    }
                case .string, .multilineString:
                    for macro in macros(in: token.value) where Catalog.lookup(macro: macro) == nil {
                        missing.insert("macro:\(Catalog.normalize(macro: macro))")
                    }
                default:
                    break
                }
                index += 1
            }
            return missing.sorted()
        }

        /// The single innermost entry at a position, the IDE's hover query.
        public static func hover(source: String, line: Int, column: Int, locale: String = "en") -> PositionedEntry? {
            annotate(source: source, locale: locale)
                .filter { $0.contains(line: line, column: column) }
                .last
        }

        /// Every `___MACRO___` occurrence in a string value, scanned left to right and
        /// non-greedily so adjacent macros split correctly.
        public static func macros(in text: String) -> [String] {
            var found: [String] = []
            var search = text[text.startIndex...]
            while let start = search.range(of: "___") {
                guard let end = search[start.upperBound...].range(of: "___") else { break }
                let name = String(search[start.lowerBound ..< end.upperBound])
                // Reject runs that contain whitespace or newlines (not macro material).
                if !name.dropFirst(3).dropLast(3).isEmpty,
                   name.dropFirst(3).dropLast(3).allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == ":" || $0 == "*" })
                {
                    found.append(name)
                    search = search[end.upperBound...]
                } else {
                    search = search[search.index(after: start.lowerBound)...]
                }
            }
            return found
        }

        // MARK: Context derivation

        /// For each token index, the construct whose body it sits in (innermost CST node wins).
        static func contextKinds(tokens: [Token], tree: SyntaxNode?) -> [Catalog.Context] {
            var contexts = [Catalog.Context](repeating: .template, count: tokens.count + 1)
            guard let tree else { return contexts }
            tree.walk { node, _ in
                let context: Catalog.Context? = switch node.kind {
                case .template: .template
                case .option: .option
                case .unit: .unit
                case .node: .node
                case .letBinding, .directory: nil
                }
                if let context {
                    for i in node.tokenRange where i < contexts.count {
                        contexts[i] = context
                    }
                }
            }
            return contexts
        }

        /// Construct-keyword positions: token index -> keyword, derived from the CST so an IDENT
        /// that merely LOOKS like a keyword (a dictionary key named "option") is not documented
        /// as one. A construct node's first token IS its introducing keyword.
        static func keywordPositions(tree: SyntaxNode?) -> [Int: String] {
            var positions: [Int: String] = [:]
            tree?.walk { node, _ in
                switch node.kind {
                case .template, .option, .unit, .node, .directory:
                    positions[node.tokenRange.lowerBound] = node.kind.rawValue
                case .letBinding:
                    break
                }
            }
            return positions
        }

        private static func positioned(_ entry: Entry, at token: Token) -> PositionedEntry {
            // Scanner-recorded end positions: source-exact across escapes, raw delimiters, and
            // multi-line lexemes (estimating from the cooked value was the audited defect).
            PositionedEntry(
                startLine: token.line, startColumn: token.column,
                endLine: token.endLine, endColumn: token.endColumn,
                entry: entry,
            )
        }
    }
}
