import UITestPageObjects
import XCTest

/// Drives the SwiftUI desktop framework browser through the Page Object Model. Selecting a
/// framework must load its document into the reader (not leave the empty "Select a
/// framework" state). The same page object backs the mobile and AppKit targets; only the
/// running app differs. This app reads from a live `cupertino serve` subprocess.
final class FrameworkBrowserUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSelectingFrameworkShowsReader() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-mock"]
        app.launch()

        Page.FrameworkBrowser(app: app)
            .verifyIsDisplayed()
            .selectFramework("swiftui")
            .verifyReaderShown()
    }
}
