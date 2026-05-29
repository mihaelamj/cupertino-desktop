import DesktopModels
import Observation

public extension CupertinoDesktop.Feature.DocReader {
    /// UI-agnostic view model for the documentation reader. Both UI frameworks
    /// bind to this same type. Renders `read_document` content in milestone M2.
    @Observable
    @MainActor
    final class Model {
        public init() {}
    }
}
