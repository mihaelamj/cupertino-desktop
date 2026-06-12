import UITestPageObjects
import XCTest

/// Drives the framework browser through the Page Object Model. Selecting a framework must
/// load its document into the reader (not leave the empty "Select a framework" state).
final class FrameworkBrowserUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSelectingFrameworkShowsReader() {
        let app = XCUIApplication()
        app.launch()

        Page.FrameworkBrowser(app: app)
            .verifyIsDisplayed()
            .selectDatabase("appleDocs")
            .selectFramework("swiftui")
            .verifyReaderShown()
    }
}
