import Observation

extension UI {
    /// The framework-agnostic root view model both UI packages bind to: SwiftUI
    /// via `@Bindable`, AppKit via `withObservationTracking`. Holds top-level app
    /// state (selection, connection status). Milestone M0 placeholder.
    @Observable
    @MainActor
    public final class RootModel {
        /// The framework currently selected in the sidebar, if any.
        public var selectedFrameworkID: String?

        public init(selectedFrameworkID: String? = nil) {
            self.selectedFrameworkID = selectedFrameworkID
        }
    }
}
