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

        /// The user-facing display name for the source.
        public var displayName: String {
            switch self {
            case .appleDocs: "Apple Developer Documentation"
            case .hig: "Human Interface Guidelines"
            case .swiftEvolution: "Swift Evolution"
            case .swiftOrg: "Swift.org"
            case .swiftBook: "The Swift Programming Language Book"
            case .appleArchive: "Apple Archive"
            case .samples: "Sample Projects"
            case .packages: "Swift Packages"
            }
        }

        /// Context-sensitive term for the list items of this source (e.g., "Proposals" for Swift Evolution).
        public var itemTerm: String {
            switch self {
            case .appleDocs, .appleArchive:
                "Frameworks"
            case .hig:
                "Guidelines"
            case .swiftEvolution:
                "Proposals"
            case .swiftOrg:
                "Articles"
            case .swiftBook:
                "Chapters"
            case .samples:
                "Samples"
            case .packages:
                "Packages"
            }
        }

        /// Context-sensitive singular term for the list items of this source (e.g., "proposal" for Swift Evolution).
        public var singularItemTerm: String {
            switch self {
            case .appleDocs, .appleArchive:
                "framework"
            case .hig:
                "guideline"
            case .swiftEvolution:
                "proposal"
            case .swiftOrg:
                "article"
            case .swiftBook:
                "chapter"
            case .samples:
                "sample"
            case .packages:
                "package"
            }
        }
    }
}
