extension Model {
    /// A sample-code project (`list_samples` / `read_sample`). `filePaths` is
    /// empty until the project is read in full.
    public struct SampleProject: Identifiable, Hashable, Sendable {
        public let id: String
        public let title: String
        public let framework: String?
        public let filePaths: [String]

        public init(id: String, title: String, framework: String?, filePaths: [String] = []) {
            self.id = id
            self.title = title
            self.framework = framework
            self.filePaths = filePaths
        }
    }
}
