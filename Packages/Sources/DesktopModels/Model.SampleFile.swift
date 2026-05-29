extension Model {
    /// A single source file inside a sample project (`read_sample_file`).
    /// `contents` arrives already syntax-highlighted from the backend.
    public struct SampleFile: Hashable, Sendable {
        public let projectID: String
        public let path: String
        public let contents: String

        public init(projectID: String, path: String, contents: String) {
            self.projectID = projectID
            self.path = path
            self.contents = contents
        }
    }
}
