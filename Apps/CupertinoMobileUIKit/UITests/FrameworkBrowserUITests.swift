import UITestPageObjects
import XCTest

/// Drives the UIKit framework browser through the Page Object Model. Selecting a framework
/// must load its document into the reader (not leave the empty "Select a framework" state).
/// The same page object backs the SwiftUI and AppKit targets; only the running app differs.
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
