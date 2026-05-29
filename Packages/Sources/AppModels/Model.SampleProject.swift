public extension Model {
    /// A sample-code project (`listSamples` / `readSample`). `readme` and `filePaths`
    /// are empty/nil until the project is read in full.
    struct SampleProject: Identifiable, Hashable, Sendable, Codable {
        public let id: SampleID
        public let title: String
        public let summary: String
        public let frameworks: [String]
        public let readme: String?
        public let webURL: String?
        public let filePaths: [String]
        public let fileCount: Int
        public let deploymentTargets: [Availability.Platform: String]

        public init(
            id: SampleID,
            title: String,
            summary: String = "",
            frameworks: [String] = [],
            readme: String? = nil,
            webURL: String? = nil,
            filePaths: [String] = [],
            fileCount: Int = 0,
            deploymentTargets: [Availability.Platform: String] = [:],
        ) {
            self.id = id
            self.title = title
            self.summary = summary
            self.frameworks = frameworks
            self.readme = readme
            self.webURL = webURL
            self.filePaths = filePaths
            self.fileCount = fileCount
            self.deploymentTargets = deploymentTargets
        }
    }
}
