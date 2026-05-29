public extension Model {
    /// A file-level search hit inside samples (distinct from a whole project).
    struct SampleFileHit: Identifiable, Hashable, Sendable, Codable {
        public let id: String
        public let projectID: SampleID
        public let path: String
        public let filename: String
        public let snippet: String
        public let score: Double

        public init(
            id: String,
            projectID: SampleID,
            path: String,
            filename: String,
            snippet: String,
            score: Double,
        ) {
            self.id = id
            self.projectID = projectID
            self.path = path
            self.filename = filename
            self.snippet = snippet
            self.score = score
        }
    }
}
