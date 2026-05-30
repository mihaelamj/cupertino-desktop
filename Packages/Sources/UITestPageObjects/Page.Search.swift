import AppCore
import XCTest

public extension Page {
    /// Page object for the search screen: type a query and assert results, then a result
    /// can be opened into the reader. Chainable.
    @MainActor
    open class Search: Base {
        private typealias IDs = UI.AccessibilityID.Search

        @discardableResult
        open func verifyIsDisplayed() -> Self {
            assertExists(IDs.field)
            return self
        }

        @discardableResult
        open func search(_ query: String) -> Self {
            let field = waitForElement(IDs.field)
            field.tap()
            field.typeText(query)
            return self
        }

        @discardableResult
        open func verifyHasResults(timeout: TimeInterval = 15) -> Self {
            assertExists(IDs.results, timeout: timeout)
            return self
        }
    }
}
