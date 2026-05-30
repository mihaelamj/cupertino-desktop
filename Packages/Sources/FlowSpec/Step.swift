/// A single step in a FlowSpec scenario, decoded from the `{ verb, target, arg? }` shape.
public struct Step: Codable, Sendable, Equatable {
    public let verb: Verb
    public let target: String
    public let arg: String?

    public init(verb: Verb, target: String, arg: String? = nil) {
        self.verb = verb
        self.target = target
        self.arg = arg
    }

    /// `verb:target`, the lookup key every step registry uses.
    public var key: String {
        "\(verb.rawValue):\(target)"
    }
}
