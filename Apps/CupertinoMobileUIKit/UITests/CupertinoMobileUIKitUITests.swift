import XCTest

/// End-to-end check of the one critical mobile flow that unit tests cannot reach:
/// tapping a framework in the sidebar must push and render its document on a compact
/// iPhone. This exercises `UISplitViewController`'s collapse-and-`show(.secondary)`
/// path, which changed when the shell moved to a two-column split. UI automation needs
/// XCTest (Swift Testing has no driver), the sanctioned exception for the E2E tier.
final class CupertinoMobileUIKitUITests: XCTestCase {
    @MainActor
    func testSelectingFrameworkPushesItsDocument() {
        let app = XCUIApplication()
        app.launch()

        let frameworkRow = app.staticTexts["UIKit"]
        XCTAssertTrue(frameworkRow.waitForExistence(timeout: 10), "the framework list should populate from the backend")
        frameworkRow.tap()

        // On compact width the detail is pushed; its navigation title is the document
        // title (the first markdown heading), so its appearance proves the navigation.
        XCTAssertTrue(
            app.navigationBars["UIKit"].waitForExistence(timeout: 10),
            "tapping a framework should push its document onto the navigation stack",
        )

        // The document loads asynchronously (search then read), so wait for the text
        // view's value to contain the real abstract rather than reading it immediately.
        let body = app.textViews.firstMatch
        let rendered = expectation(for: NSPredicate(format: "value CONTAINS %@", "event-driven"), evaluatedWith: body)
        wait(for: [rendered], timeout: 10)
    }
}
