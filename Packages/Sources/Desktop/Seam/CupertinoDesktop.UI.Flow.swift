import DesktopModels

public extension CupertinoDesktop.UI {
    /// The top-level seam: a framework's combined flow assembles its screens into
    /// a single root controller. Both app targets call `makeRootController()`
    /// identically; only the injected conformer (AppKit vs SwiftUI) differs.
    @MainActor
    protocol Flow {
        func makeRootController() -> CupertinoDesktop.UI.ViewController
    }
}
