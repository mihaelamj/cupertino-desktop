import Foundation

public extension Model {
    /// A dynamic item in the hierarchical source structure.
    struct HierarchyItem: Identifiable, Hashable, Sendable, Codable {
        public let id: String
        public let title: String
        public let description: String?
        public let hasChildren: Bool

        public init(id: String, title: String, description: String? = nil, hasChildren: Bool) {
            self.id = id
            self.title = title
            self.description = description
            self.hasChildren = hasChildren
        }
    }
}
