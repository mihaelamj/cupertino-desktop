import AppCore
import FlowSpec
import UITestPageObjects
import XCTest

/// Runs declarative FlowSpec scenarios (`scenarios/*.json`) against the running app through
/// the page-object `ScenarioRegistry`. The same scenario files can drive the AppKit and
/// UIKit apps once they wire an equivalent UI-test target.
final class ScenarioUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFrameworkReaderScenario() throws {
        try runScenario("framework-reader")
    }

    @MainActor
    func testReaderTextSizeScenario() throws {
        try runScenario("reader-text-size")
    }

    @MainActor
    func testFrameworkSearchSortScenario() throws {
        try runScenario("framework-search-sort")
    }

    @MainActor
    func testOrientationAdaptivity() {
        let app = XCUIApplication()
        app.launchEnvironment["CUPERTINO_UI_TESTING"] = "1"
        app.launch()

        let device = XCUIDevice.shared
        device.orientation = .portrait

        // Verify databases sidebar is visible on launch
        let sidebar = app.descendants(matching: .any).matching(identifier: UI.AccessibilityID.FrameworkBrowser.sidebar).firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))

        // Tap the Apple Developer Documentation source
        let appleDocsRow = app.descendants(matching: .any).matching(identifier: UI.AccessibilityID.FrameworkBrowser.sourceRow("appleDocs")).firstMatch
        XCTAssertTrue(appleDocsRow.waitForExistence(timeout: 5))
        appleDocsRow.tap()

        // Rotate simulator to landscape
        device.orientation = .landscapeLeft

        // Verify search field exists and is responsive
        let searchField = app.searchFields.firstMatch.exists ? app.searchFields.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // Rotate back to portrait
        device.orientation = .portrait
        XCTAssertTrue(searchField.exists)
    }

    // In-document link taps are not driven by UI tests: XCUITest cannot reliably tap an
    // inline link inside a text view (it surfaces as static text). Link resolution is covered
    // by MarkdownRendering's `documentURL` unit test. The `content-unavailable` scenario runs
    // on the desktop targets only, where the detail column is visible at launch (the compact
    // iPhone layout pushes the detail off screen).

    // MARK: - Helpers

    /// Launch the app, load `scenarios/<id>.json`, and run it through the registry.
    @MainActor
    private func runScenario(_ id: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let app = XCUIApplication()
        app.launchEnvironment["CUPERTINO_UI_TESTING"] = "1"
        app.launch()
        let scenario = try ScenarioLoader.load(id: id, searchURL: Self.scenariosURL)
        do {
            try ScenarioRunner(registry: Page.ScenarioRegistry(app: app)).run(scenario)
        } catch {
            XCTFail("\(error)", file: file, line: line)
        }
    }

    /// The repo-root `scenarios/` directory, resolved from this source file's location:
    /// .../cupertino-desktop/Apps/CupertinoMobileSwiftUI/UITests/<this file>.
    private static let scenariosURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // UITests
        .deletingLastPathComponent() // CupertinoMobileSwiftUI
        .deletingLastPathComponent() // Apps
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("scenarios", isDirectory: true)
}
