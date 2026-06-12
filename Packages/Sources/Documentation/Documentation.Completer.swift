import Foundation
import Lexer
import Parser

public extension Documentation {
    /// One completion the IDE can offer at a position. `label` is the friendly display name,
    /// `insertText` the exact text to insert (the raw spelling), `detail` the one-line help.
    struct CompletionItem: Equatable, Sendable {
        public let kind: Entry.Kind
        public let label: String
        public let insertText: String
        public let detail: String
        public let body: String

        public init(kind: Entry.Kind, label: String, insertText: String, detail: String, body: String) {
            self.kind = kind
            self.label = label
            self.insertText = insertText
            self.detail = detail
            self.body = body
        }

        init(_ entry: Entry, insertText: String? = nil) {
            kind = entry.kind
            label = entry.displayName
            self.insertText = insertText ?? entry.name
            detail = entry.title
            body = entry.body
        }
    }

    /// Position-aware completion over the same recovering front end the hover stream uses. The
    /// syntactic half comes from the grammar's FIRST sets (which constructs are legal in the
    /// enclosing body); the vocabulary half comes from the catalog (which keys, which type
    /// values, which macros).
    enum Completer {
        public static func complete(source: String, line: Int, column: Int, locale: String = "en") -> [CompletionItem] {
            let (tokens, _) = Lexer(code: source).tokenizeRecovering()
            let parser = Parser(tokens: tokens)
            _ = parser.parseRecovering()
            let contexts = Annotator.contextKinds(tokens: tokens, tree: parser.syntaxTree)

            // The token the cursor is in or immediately after (last token starting at or before).
            var cursorIndex = -1
            for (i, token) in tokens.enumerated() {
                if (token.line, token.column) <= (line, column) { cursorIndex = i } else { break }
            }
            let context: Catalog.Context = cursorIndex >= 0 && cursorIndex < contexts.count ? contexts[cursorIndex] : .template

            // INSIDE a string value (span containment, not merely after its start): offer macros,
            // the only vocabulary that lives in strings.
            if cursorIndex >= 0 {
                let token = tokens[cursorIndex]
                if token.type == .string || token.type == .multilineString {
                    let lineCount = token.value.split(separator: "\n", omittingEmptySubsequences: false).count
                    let lastLine = token.line + lineCount - 1
                    // Conservative span: quotes and escapes make the exact end column fuzzy, so the
                    // single-line end allows the raw lexeme plus delimiters.
                    let inside = line < lastLine || (line == token.line && lineCount == 1
                        ? column >= token.column && column <= token.column + token.value.count + 6
                        : line <= lastLine)
                    if inside {
                        return macroCompletions(locale: locale)
                    }
                }
            }

            // Right after `let`: offer the key vocabulary of the enclosing construct.
            if cursorIndex >= 0, tokens[cursorIndex].type == .letKeyword {
                return keyCompletions(context: context, locale: locale)
            }

            // Right after `let Key =`: offer value vocabulary where one exists.
            if cursorIndex >= 1, tokens[cursorIndex].type == .equals,
               cursorIndex >= 2, tokens[cursorIndex - 2].type == .letKeyword
            {
                let key = tokens[cursorIndex - 1].value
                if key == "Type", context == .option {
                    return Catalog.optionTypeValues(locale: locale).values
                        .sorted { $0.name < $1.name }
                        .map { CompletionItem($0, insertText: "\"\($0.name)\"") }
                }
                return []
            }

            // Item position: the constructs legal in this body, straight from FIRST(item).
            return itemKeywordCompletions(context: context, topLevel: tokens.isEmpty || cursorIndex < 0, locale: locale)
        }

        static func keyCompletions(context: Catalog.Context, locale: String) -> [CompletionItem] {
            let table: [String: Entry] = switch context {
            case .template: Catalog.manifestKeys(locale: locale)
            case .option: Catalog.optionKeys(locale: locale)
            case .unit, .node: Catalog.definitionKeys(locale: locale)
            }
            return table.values.sorted { $0.name < $1.name }.map { CompletionItem($0) }
        }

        static func macroCompletions(locale: String) -> [CompletionItem] {
            Catalog.macros(locale: locale).values
                .sorted { $0.name < $1.name }
                .map { entry in
                    // Families insert their parameterized shape with the star as the edit point.
                    CompletionItem(entry, insertText: entry.name)
                }
        }

        /// FIRST(item) per construct body, the grammar's own completion table.
        static func itemKeywordCompletions(context: Catalog.Context, topLevel: Bool, locale: String) -> [CompletionItem] {
            if topLevel {
                return [Catalog.lookup(keyword: "template", locale: locale)].compactMap(\.self).map { CompletionItem($0) }
            }
            let names: [String] = switch context {
            case .template: ["let", "option", "node", "directory"]
            case .option: ["let", "unit"]
            case .unit: ["let", "node"]
            case .node: ["let"]
            }
            return names.compactMap { Catalog.lookup(keyword: $0, locale: locale) }.map { CompletionItem($0) }
        }
    }
}
