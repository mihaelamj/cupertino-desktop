public extension Backend {
    /// The whole backend contract, composed by interface segregation from the
    /// capability slices. One adapter implements all of it, because one cupertino
    /// instance answers all of it; features depend on the narrow slices they use
    /// (`Searching`, `DocumentReading`, ...) rather than this composition.
    ///
    /// Pure domain verbs returning `AppModels` value types; no MCP, JSON-RPC, or
    /// cupertino types appear here. Adapters are named by locality, never protocol:
    /// `Backend.LocalSubprocess` (out-of-process, local `cupertino serve`) and
    /// `Backend.LocalEmbedded` (in-process). A remote adapter is future. The full
    /// contract is specified in docs/PROTOCOL.md.
    typealias Documentation = CodeIntelligence
        & Connecting
        & DocumentReading
        & FrameworkBrowsing
        & SampleBrowsing
        & Searching
}
