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

    // The `document-link` scenario (scenarios/document-link.json) is intentionally not run
    // here: XCUITest cannot address an individual SwiftUI `Text` link, so the tap times out.
    // Link resolution is covered by MarkdownRendering's `documentURL` unit test; the scenario
    // is kept for a future UIKit/AppKit UI-test target, whose text-view links are accessible.

    // MARK: - Helpers

    /// Launch the app, load `scenarios/<id>.json`, and run it through the registry.
    @MainActor
    private func runScenario(_ id: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let app = XCUIApplication()
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
