import DesktopModels
import DesktopUI
import SearchFeature

public extension CupertinoDesktop.UI.Search {
    /// AppKit conformer of the shared `Search.Providing` seam.
    @MainActor
    struct AppKitScreen: CupertinoDesktop.UI.Search.Providing {
        public init() {}

        public func makeController(
            model: CupertinoDesktop.Feature.Search.Model,
        ) -> CupertinoDesktop.UI.ViewController {
            AppKitController(model: model)
        }
    }
}
