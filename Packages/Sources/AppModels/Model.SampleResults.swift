public extension Model {
    /// Sample search returns both project matches and file matches, which are
    /// distinct natures, so we keep them apart rather than flattening to one list.
    struct SampleResults: Hashable, Sendable, Codable {
        public let projects: [SampleProject]
        public let files: [SampleFileHit]

        public init(projects: [SampleProject], files: [SampleFileHit]) {
            self.projects = projects
            self.files = files
        }
    }
}
