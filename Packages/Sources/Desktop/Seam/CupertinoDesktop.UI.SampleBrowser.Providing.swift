import DesktopModels
import SampleBrowserFeature

public extension CupertinoDesktop.UI.SampleBrowser {
    /// Builds the sample code browser screen for a given view model. Implemented
    /// once per framework; both return the same `ViewController` type.
    @MainActor
    protocol Providing {
        func makeController(model: CupertinoDesktop.Feature.SampleBrowser.Model) -> CupertinoDesktop.UI.ViewController
    }
}
