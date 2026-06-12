import Foundation

public extension Documentation {
    /// One unit of help: what something IS, said well enough to be a tooltip. Entries are pure
    /// knowledge; position arrives when an `Annotator` attaches one to a source range.
    struct Entry: Equatable, Sendable {
        /// What vocabulary the documented name belongs to. The IDE may style hovers per kind.
        public enum Kind: String, Sendable {
            /// A construct keyword of the DSL (`template`, `let`, `option`, `unit`, `node`, `directory`).
            case keyword
            /// A top-level TemplateInfo key (`Kind`, `Identifier`, `Options`, ...).
            case manifestKey
            /// A key inside an option block (`Type`, `Default`, `Values`, `Units`, ...).
            case optionKey
            /// A key inside a node/definition block (`Path`, `Group`, `content`, ...).
            case definitionKey
            /// A `___MACRO___` replacement site inside a string value.
            case macro
            /// A value of the option `Type` field (`popup`, `checkbox`, `text`, ...).
            case optionTypeValue
            /// Anything known only by its context (a dictionary key passed verbatim).
            case contextual
        }

        public let kind: Kind
        /// The canonical name (for macro families, the wildcard form, e.g. `___VARIABLE_*___`).
        public let name: String
        /// The human-friendly name the IDE SHOWS (macro spellings are hostile; users see
        /// "Product Name (identifier-safe)", the stored text stays `___PACKAGENAMEASIDENTIFIER___`).
        public let displayName: String
        /// One-line summary, the tooltip headline.
        public let title: String
        /// The full help body: what it does, what shapes it takes, what consumes it.
        public let body: String

        public init(kind: Kind, name: String, displayName: String? = nil, title: String, body: String) {
            self.kind = kind
            self.name = name
            self.displayName = displayName ?? name
            self.title = title
            self.body = body
        }
    }

    /// An `Entry` attached to a half-open source range (1-based lines and columns), the form the
    /// IDE consumes: point inside the range, show the entry.
    struct PositionedEntry: Equatable, Sendable {
        public let startLine: Int
        public let startColumn: Int
        public let endLine: Int
        public let endColumn: Int
        public let entry: Entry

        public init(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int, entry: Entry) {
            self.startLine = startLine
            self.startColumn = startColumn
            self.endLine = endLine
            self.endColumn = endColumn
            self.entry = entry
        }

        public func contains(line: Int, column: Int) -> Bool {
            if line < startLine || line > endLine { return false }
            if line == startLine, column < startColumn { return false }
            if line == endLine, column >= endColumn { return false }
            return true
        }
    }
}
