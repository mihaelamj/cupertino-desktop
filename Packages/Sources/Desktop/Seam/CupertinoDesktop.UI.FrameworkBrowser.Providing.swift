import DesktopModels
import FrameworkBrowserFeature

public extension CupertinoDesktop.UI.FrameworkBrowser {
    /// Builds the framework browser screen for a given view model. Implemented
    /// once per framework; both return the same `ViewController` type.
    @MainActor
    protocol Providing {
        func makeController(
            model: CupertinoDesktop.Feature.FrameworkBrowser.Model,
        ) -> CupertinoDesktop.UI.ViewController
    }
}
