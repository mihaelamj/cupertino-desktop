import DesktopModels
import Observation

public extension CupertinoDesktop.Feature.FrameworkBrowser {
    /// UI-agnostic view model for the framework browser sidebar. Both UI
    /// frameworks bind to this same type. Loads `list_frameworks` in milestone M1.
    @Observable
    @MainActor
    final class Model {
        public init() {}
    }
}
