public extension Model {
    /// Where a documentation hit came from. Drives icon, grouping, and which
    /// adapter source/tool answered it. The doc-like sources (everything except
    /// `samples` and `packages`) share the `DocHit` shape. See docs/PROTOCOL.md.
    enum Source: String, Sendable, Codable, CaseIterable {
        case appleDocs
        case appleArchive
        case hig
        case swiftEvolution
        case swiftOrg
        case swiftBook
        case samples
        case packages

        /// The URI scheme cupertino uses for this source (e.g. `apple-docs`).
        public var scheme: String {
            switch self {
            case .appleDocs: "apple-docs"
            case .appleArchive: "apple-archive"
            case .hig: "hig"
            case .swiftEvolution: "swift-evolution"
            case .swiftOrg: "swift-org"
            case .swiftBook: "swift-book"
            case .samples: "samples"
            case .packages: "packages"
            }
        }
    }
}
