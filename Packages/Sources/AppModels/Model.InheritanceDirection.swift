public extension Model {
    /// Which way to walk a type hierarchy (`inheritance`). Our names read by intent;
    /// the adapter maps them to cupertino's `up`/`down`/`both` direction.
    enum InheritanceDirection: String, Sendable, Codable {
        case ancestors
        case descendants
        case both
    }
}
