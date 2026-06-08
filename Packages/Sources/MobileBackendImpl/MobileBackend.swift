import BackendAPI
import CupertinoDataEngine
import CupertinoDataKit
import LocalEmbeddedBackend

/// Composition root for the Mobile (iOS) backend. Mirrors `MacBackend`, but wires the
/// in-process embedded adapter instead of MCP-over-subprocess.
///
/// The read engine is a **constructor-injected strategy** (`any Search.DocumentReading`,
/// optionally paired with `Search.SymbolReading`, `Sample.Index.Reader`, and
/// `Search.PackagesSearcher`). App targets get back an opaque
/// `any Backend.Documentation` and never see CupertinoDataKit, CupertinoDataEngine,
/// storage paths, or the `cupertino` package.
public enum MobileBackend {
    /// Build the mobile backend over Cupertino's embedded engine facade.
    public static func live(engine: CupertinoDataEngine) async -> any Backend.Documentation {
        let sampleReader = try? await engine.samples()
        let packageSearcher = try? await engine.packages()
        return live(
            dataSource: engine,
            symbolReader: engine,
            sampleReader: sampleReader,
            packageSearcher: packageSearcher,
        )
    }

    /// Build the iOS backend over an injected read source.
    public static func live(
        dataSource: any Search.DocumentReading,
        symbolReader: (any Search.SymbolReading)? = nil,
        sampleReader: (any Sample.Index.Reader)? = nil,
        packageSearcher: (any Search.PackagesSearcher)? = nil,
    ) -> any Backend.Documentation {
        Backend.LocalEmbedded(
            dataSource: dataSource,
            symbolReader: symbolReader,
            sampleReader: sampleReader,
            packageSearcher: packageSearcher,
        )
    }

    /// A development backend over `MockReader` (a hand-written `Search.DocumentReading`
    /// stand-in). Returns mock content, not the real corpus; production composition uses
    /// `live(engine:)` over the real engine.
    public static func mock() -> any Backend.Documentation {
        live(dataSource: MockReader())
    }
}
