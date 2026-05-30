import BackendAPI
import CupertinoDataKit
import LocalEmbeddedBackend

/// Composition root for the Mobile (iOS) backend. Mirrors `MacBackend`, but wires the
/// in-process embedded adapter instead of MCP-over-subprocess.
///
/// The read engine is a **constructor-injected strategy** (`any Search.DocumentReading`),
/// so this root holds no concrete engine and fabricates no data: the iOS app supplies
/// the real reader (the future `CupertinoDataEngine`, or a bundled-corpus reader) at the
/// composition site. App targets get back an opaque `any Backend.Documentation` and never
/// see CupertinoDataKit or the `cupertino` package.
public enum MobileBackend {
    /// Build the iOS backend over an injected read source.
    public static func live(dataSource: any Search.DocumentReading) -> any Backend.Documentation {
        Backend.LocalEmbedded(dataSource: dataSource)
    }

    /// A development backend over `MockReader` (a hand-written `Search.DocumentReading`
    /// stand-in), for running the iOS app before `CupertinoDataEngine` is published.
    /// Returns mock content, not the real corpus; replace with `live(dataSource:)` over
    /// the real engine once it ships, a one-line change at the composition root.
    public static func mock() -> any Backend.Documentation {
        live(dataSource: MockReader())
    }
}
