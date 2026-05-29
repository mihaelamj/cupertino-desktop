extension Model {
    /// A documentation framework as listed by the backend (`list_frameworks`).
    public struct Framework: Identifiable, Hashable, Sendable {
        public let id: String
        public let name: String
        public let documentCount: Int

        public init(id: String, name: String, documentCount: Int) {
            self.id = id
            self.name = name
            self.documentCount = documentCount
        }
    }
}
