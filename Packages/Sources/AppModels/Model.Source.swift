public extension Model {
    /// Where a documentation hit came from. Drives icon, grouping, and which
    /// adapter source/tool answered it. The doc-like sources (everything except
    /// `samples` and `packages`) share the `DocHit` shape. See docs/PROTOCOL.md.
    struct Source: Hashable, Sendable, Codable, RawRepresentable, CaseIterable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        // MARK: - Codable (preserve bare-string wire format)

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            rawValue = try container.decode(String.self)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        // MARK: - Historical canonical constants

        public static let appleDocs = Source(rawValue: "appleDocs")
        public static let appleArchive = Source(rawValue: "appleArchive")
        public static let hig = Source(rawValue: "hig")
        public static let swiftEvolution = Source(rawValue: "swiftEvolution")
        public static let swiftOrg = Source(rawValue: "swiftOrg")
        public static let swiftBook = Source(rawValue: "swiftBook")
        public static let samples = Source(rawValue: "samples")
        public static let packages = Source(rawValue: "packages")

        public static var allCases: [Source] {
            [.appleDocs, .appleArchive, .hig, .swiftEvolution, .swiftOrg, .swiftBook, .samples, .packages]
        }

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
            default:
                // Fallback: lowercase with dashes
                rawValue.replacingOccurrences(of: "([A-Z])", with: "-$1", options: .regularExpression).lowercased()
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
            default:
                rawValue.capitalized
            }
        }

        /// The system image icon name for this source.
        public var iconName: String {
            switch self {
            case .appleDocs: "books.vertical"
            case .hig: "sidebar.leading"
            case .swiftEvolution: "arrow.up.forward.circle"
            case .swiftOrg: "globe"
            case .swiftBook: "book"
            case .appleArchive: "archivebox"
            case .samples: "shippingbox"
            case .packages: "shippingbox.fill"
            default:
                "doc.text"
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
            default:
                "Items"
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
            default:
                "item"
            }
        }
    }
}
