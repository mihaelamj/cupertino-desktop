import FlowSpec
import UITestPageObjects
import XCTest

/// Runs the declarative FlowSpec scenarios (`scenarios/*.json`) against the running SwiftUI
/// desktop app through the page-object `ScenarioRegistry`, the same scenario files the
/// mobile targets drive. This app talks to a live `cupertino serve` subprocess, so the two
/// scenarios run here are the backend-agnostic ones (identifier-based, no hardcoded document
/// text). The `document-link` scenario is not run: XCUITest cannot address an individual
/// SwiftUI `Text` link, and its target text is mock-corpus specific; it runs on the
/// mock-backed UIKit target instead.
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

    // MARK: - Helpers

    /// Launch the app, load `scenarios/<id>.json`, and run it through the registry.
    @MainActor
    private func runScenario(_ id: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-mock"]
        app.launch()
        let scenario = try ScenarioLoader.load(id: id, searchURL: Self.scenariosURL)
        do {
            try ScenarioRunner(registry: Page.ScenarioRegistry(app: app)).run(scenario)
        } catch {
            XCTFail("\(error)", file: file, line: line)
        }
    }

    /// The repo-root `scenarios/` directory, resolved from this source file's location:
    /// .../cupertino-desktop/Apps/CupertinoDesktopSwiftUI/UITests/<this file>.
    private static let scenariosURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // UITests
        .deletingLastPathComponent() // CupertinoDesktopSwiftUI
        .deletingLastPathComponent() // Apps
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("scenarios", isDirectory: true)
}
