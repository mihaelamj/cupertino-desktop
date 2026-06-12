import Foundation

public struct FileInfo: Sendable {
    public let type: String // "text" or "binary"
    public let content: String

    public init(type: String, content: String) {
        self.type = type
        self.content = content
    }
}
