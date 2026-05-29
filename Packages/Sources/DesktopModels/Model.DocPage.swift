extension Model {
    /// A rendered documentation page (`read_document`). Carries the raw markdown
    /// plus the parsed title so the reader renders without a second fetch.
    public struct DocPage: Hashable, Sendable {
        public let uri: DocURI
        public let title: String
        public let markdown: String

        public init(uri: DocURI, title: String, markdown: String) {
            self.uri = uri
            self.title = title
            self.markdown = markdown
        }
    }
}
