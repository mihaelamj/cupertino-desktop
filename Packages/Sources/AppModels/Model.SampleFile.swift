public extension Model {
    /// A single source file inside a sample project (`readSampleFile`).
    struct SampleFile: Hashable, Sendable, Codable {
        public let projectID: SampleID
        public let path: String
        public let filename: String
        public let language: String?
        public let contents: String

        public init(
            projectID: SampleID,
            path: String,
            filename: String,
            language: String? = nil,
            contents: String,
        ) {
            self.projectID = projectID
            self.path = path
            self.filename = filename
            self.language = language
            self.contents = contents
        }
    }
}
