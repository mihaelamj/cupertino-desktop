public extension Model {
    /// The result of `searchEverything`: each source nature kept in its own bucket
    /// (not flattened), plus the names of any sources that could not answer.
    struct UnifiedResults: Hashable, Sendable, Codable {
        public let docs: [DocHit]
        public let samples: SampleResults
        public let packages: [PackageHit]
        public let degraded: [String]

        public init(
            docs: [DocHit],
            samples: SampleResults,
            packages: [PackageHit],
            degraded: [String] = [],
        ) {
            self.docs = docs
            self.samples = samples
            self.packages = packages
            self.degraded = degraded
        }
    }
}
