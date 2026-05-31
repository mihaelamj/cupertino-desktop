import FlowSpec
import UITestPageObjects
import XCTest

/// Runs the declarative FlowSpec scenarios (`scenarios/*.json`) against the running AppKit
/// desktop app through the page-object `ScenarioRegistry`, the same scenario files the
/// mobile and SwiftUI targets drive. Launched with `-uitest-mock`, the app injects the
/// deterministic embedded corpus, so this target also runs `document-link`: AppKit renders
/// the document into an `NSTextView`, whose inline links are exposed to XCUITest (the
/// SwiftUI target cannot run that scenario, because XCUITest cannot address a `Text` link).
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
    func testDocumentLinkScenario() throws {
        try runScenario("document-link")
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
    /// .../cupertino-desktop/Apps/CupertinoDesktopAppKit/UITests/<this file>.
    private static let scenariosURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // UITests
        .deletingLastPathComponent() // CupertinoDesktopAppKit
        .deletingLastPathComponent() // Apps
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("scenarios", isDirectory: true)
}
