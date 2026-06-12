import Foundation

public struct ValidationErrorCollection: Error, CustomStringConvertible {
    public let values: [ValidationError]

    public init(_ values: [ValidationError]) {
        self.values = values
    }

    public var description: String {
        values.map(\.description).joined(separator: "\n")
    }
}
