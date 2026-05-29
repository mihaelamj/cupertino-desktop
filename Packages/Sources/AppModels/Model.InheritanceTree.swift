public extension Model {
    /// The result of an inheritance walk (`inheritance`): the ancestors and
    /// descendants of a starting symbol, each a tree of nodes.
    struct InheritanceTree: Hashable, Sendable, Codable {
        public let startURI: DocURI
        public let ancestors: [Node]
        public let descendants: [Node]

        public init(startURI: DocURI, ancestors: [Node], descendants: [Node]) {
            self.startURI = startURI
            self.ancestors = ancestors
            self.descendants = descendants
        }

        public struct Node: Hashable, Sendable, Codable, Identifiable {
            public var id: String {
                uri.rawValue
            }

            public let uri: DocURI
            public let title: String
            public let children: [Node]

            public init(uri: DocURI, title: String, children: [Node] = []) {
                self.uri = uri
                self.title = title
                self.children = children
            }
        }
    }
}
