public extension Model {
    /// The kind of a documentation symbol or page. Mapped from cupertino's kind
    /// strings inside the adapters; `unknown` absorbs anything unrecognised.
    enum SymbolKind: String, Sendable, Codable, CaseIterable {
        case structure = "struct"
        case classType = "class"
        case actorType = "actor"
        case enumeration = "enum"
        case protocolType = "protocol"
        case function
        case property
        case method
        case initializer
        case subscriptType = "subscript"
        case operatorType = "operator"
        case typeAlias
        case macro
        case enumCase = "case"
        case article
        case framework
        case unknown
    }
}
