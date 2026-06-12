import Foundation

public struct XcodeTemplateBundle: Sendable {
    public var name: String
    public var identifier: String
    public var metadata: [String: PropertyListValue]
    public var files: [String: FileInfo]
    /// Directories that contain no files (for example an empty `Media.xcassets/`). The files map is
    /// path-to-content, so an empty directory has nothing to represent it and would otherwise be lost on a
    /// round-trip; tracking it keeps the folder structure exact.
    public var emptyDirectories: [String]

    public init(name: String, identifier: String, metadata: [String: PropertyListValue], files: [String: FileInfo], emptyDirectories: [String] = []) {
        self.name = name
        self.identifier = identifier
        self.metadata = metadata
        self.files = files
        self.emptyDirectories = emptyDirectories
    }
}
