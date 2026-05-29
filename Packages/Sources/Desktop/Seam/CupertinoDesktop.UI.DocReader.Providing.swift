import DesktopModels
import DocReaderFeature

public extension CupertinoDesktop.UI.DocReader {
    /// Builds the documentation reader screen for a given view model. Implemented
    /// once per framework; both return the same `ViewController` type.
    @MainActor
    protocol Providing {
        func makeController(model: CupertinoDesktop.Feature.DocReader.Model) -> CupertinoDesktop.UI.ViewController
    }
}
