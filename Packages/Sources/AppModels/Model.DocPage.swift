public extension Model {
    /// A fully read documentation page (`readDocument`). Carries structured fields
    /// plus the raw markdown body so the reader renders without a second fetch.
    /// `read_document` returns JSON by default, so even the subprocess adapter can
    /// decode straight into this; the embedded adapter maps typed services into it.
    struct DocPage: Hashable, Sendable, Codable {
        public let uri: DocURI
        public let source: Source
        public let title: String
        public let kind: SymbolKind
        public let abstract: String?
        public let declaration: Declaration?
        public let markdown: String
        public let sections: [Section]
        public let codeExamples: [CodeExample]
        public let availability: [Availability]
        public let relationships: Relationships

        public init(
            uri: DocURI,
            source: Source,
            title: String,
            kind: SymbolKind = .unknown,
            abstract: String? = nil,
            declaration: Declaration? = nil,
            markdown: String,
            sections: [Section] = [],
            codeExamples: [CodeExample] = [],
            availability: [Availability] = [],
            relationships: Relationships = Relationships(),
        ) {
            self.uri = uri
            self.source = source
            self.title = title
            self.kind = kind
            self.abstract = abstract
            self.declaration = declaration
            self.markdown = markdown
            self.sections = sections
            self.codeExamples = codeExamples
            self.availability = availability
            self.relationships = relationships
        }

        public struct Declaration: Hashable, Sendable, Codable {
            public let code: String
            public let language: String?
            public init(code: String, language: String? = nil) {
                self.code = code
                self.language = language
            }
        }

        public struct Section: Hashable, Sendable, Codable {
            public let title: String
            public let markdown: String
            public init(title: String, markdown: String) {
                self.title = title
                self.markdown = markdown
            }
        }

        public struct CodeExample: Hashable, Sendable, Codable {
            public let code: String
            public let language: String?
            public let caption: String?
            public init(code: String, language: String? = nil, caption: String? = nil) {
                self.code = code
                self.language = language
                self.caption = caption
            }
        }

        public struct Relationships: Hashable, Sendable, Codable {
            public let conformsTo: [String]
            public let inheritsFrom: [String]
            public let conformingTypes: [String]
            public let inheritedBy: [String]
            public init(
                conformsTo: [String] = [],
                inheritsFrom: [String] = [],
                conformingTypes: [String] = [],
                inheritedBy: [String] = [],
            ) {
                self.conformsTo = conformsTo
                self.inheritsFrom = inheritsFrom
                self.conformingTypes = conformingTypes
                self.inheritedBy = inheritedBy
            }
        }
    }
}
