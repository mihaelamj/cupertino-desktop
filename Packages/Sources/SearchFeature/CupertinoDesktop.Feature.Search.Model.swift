import DesktopModels
import Observation

public extension CupertinoDesktop.Feature.Search {
    /// UI-agnostic view model for the search screen. Both the AppKit and SwiftUI
    /// screens bind to this same type. Query state and result loading land in
    /// milestone M3.
    @Observable
    @MainActor
    final class Model {
        public init() {}
    }
}
