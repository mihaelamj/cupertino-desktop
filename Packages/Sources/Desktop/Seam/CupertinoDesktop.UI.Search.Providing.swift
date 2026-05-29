import DesktopModels
import SearchFeature

public extension CupertinoDesktop.UI.Search {
    /// Builds the search screen for a given view model. Implemented once per
    /// framework (`SearchAppKit`, `SearchSwiftUI`); both return the same
    /// `ViewController` type so callers are framework-agnostic.
    @MainActor
    protocol Providing {
        func makeController(model: CupertinoDesktop.Feature.Search.Model) -> CupertinoDesktop.UI.ViewController
    }
}
