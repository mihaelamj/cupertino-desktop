import FlowSpec
import UITestPageObjects
import XCTest

/// Runs a declarative FlowSpec scenario (`scenarios/framework-reader.json`) against the
/// running app through the page-object `ScenarioRegistry`. The same scenario file can drive
/// the AppKit and UIKit apps once they wire an equivalent UI-test target.
final class ScenarioUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFrameworkReaderScenario() throws {
        let app = XCUIApplication()
        app.launch()

        // Resolve the repo-root `scenarios/` directory from this source file's location:
        // .../cupertino-desktop/Apps/CupertinoMobileSwiftUI/UITests/<this file>.
        let scenariosURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // UITests
            .deletingLastPathComponent() // CupertinoMobileSwiftUI
            .deletingLastPathComponent() // Apps
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("scenarios", isDirectory: true)

        let scenario = try ScenarioLoader.load(id: "framework-reader", searchURL: scenariosURL)
        try ScenarioRunner(registry: Page.ScenarioRegistry(app: app)).run(scenario)
    }
}
