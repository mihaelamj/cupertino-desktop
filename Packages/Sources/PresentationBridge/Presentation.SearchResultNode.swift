import AppModels

public extension Presentation {
    /// A logical search-result tree node.
    ///
    /// Group nodes have children and no URI. Leaf nodes carry the document URI that a
    /// concrete shell can open through its native navigation surface.
    struct SearchResultNode: Identifiable, Hashable, Sendable {
        public let id: String
        public let title: String
        public let subtitle: String?
        public let uri: Model.DocURI?
        public var children: [SearchResultNode]

        public init(
            id: String,
            title: String,
            subtitle: String? = nil,
            uri: Model.DocURI? = nil,
            children: [SearchResultNode] = [],
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.uri = uri
            self.children = children
        }

        public var isLeaf: Bool {
            children.isEmpty && uri != nil
        }
    }
}
