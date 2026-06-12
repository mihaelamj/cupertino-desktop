import Foundation

public struct AnyCodingKey: CodingKey {
    public var stringValue: String
    public var intValue: Int?

    public init(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    public init(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }

    public init(stringValue: String, intValue: Int?) {
        self.stringValue = stringValue
        self.intValue = intValue
    }
}
