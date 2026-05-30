import AppCore
import XCTest

public extension Page {
    /// Page object for the framework browser: select a framework and assert its document
    /// renders. Directly exercises the "select a framework -> see the document" flow that
    /// the empty-state ("Select a framework") is the failure of. Chainable.
    @MainActor
    open class FrameworkBrowser: Base {
        private typealias IDs = UI.AccessibilityID.FrameworkBrowser

        @discardableResult
        open func verifyIsDisplayed() -> Self {
            assertExists(IDs.sidebar)
            return self
        }

        /// Tap a framework row (qualified by framework id, e.g. `"swiftui"`).
        @discardableResult
        open func selectFramework(_ frameworkID: String) -> Self {
            tap(IDs.row(frameworkID))
            return self
        }

        /// Assert the reader appeared (the document loaded), i.e. the detail is showing a
        /// document rather than the empty "Select a framework" state.
        @discardableResult
        open func verifyReaderShown(timeout: TimeInterval = 15) -> Self {
            assertExists(IDs.reader, timeout: timeout)
            return self
        }
    }
}
