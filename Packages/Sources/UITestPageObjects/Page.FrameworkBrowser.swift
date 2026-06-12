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
            let appleDocsRow = element(IDs.sourceRow("appleDocs"))
            let frameworkRow = element(IDs.row(frameworkID))
            _ = appleDocsRow.waitForExistence(timeout: 5)
            if appleDocsRow.exists, !frameworkRow.exists {
                appleDocsRow.performTap()
            }

            tap(IDs.row(frameworkID))

            let firstCell = app.descendants(matching: .any).matching(identifier: "document_cell").firstMatch
            let reader = app.descendants(matching: .any).matching(identifier: IDs.reader).firstMatch
            if !reader.exists {
                if firstCell.waitForExistence(timeout: 10) {
                    firstCell.performTap()
                }
            }
            return self
        }

        /// Tap a database source row (qualified by source raw value, e.g. `"appleDocs"`).
        @discardableResult
        open func selectDatabase(_ sourceID: String) -> Self {
            tap(IDs.sourceRow(sourceID))
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
