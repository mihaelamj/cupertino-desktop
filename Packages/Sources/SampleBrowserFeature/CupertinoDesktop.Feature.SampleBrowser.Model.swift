import DesktopModels
import Observation

public extension CupertinoDesktop.Feature.SampleBrowser {
    /// UI-agnostic view model for the sample code browser. Both UI frameworks
    /// bind to this same type. Loads `list_samples` in milestone M4.
    @Observable
    @MainActor
    final class Model {
        public init() {}
    }
}
