import FlowSpec
import UITestPageObjects
import XCTest

/// Runs the declarative FlowSpec scenarios (`scenarios/*.json`) against the running UIKit
/// app through the page-object `ScenarioRegistry`, the same scenario files the SwiftUI and
/// AppKit targets drive. UIKit renders the document into a `UITextView`, whose inline links
/// are exposed to XCUITest, so this target also runs `document-link` (the SwiftUI target
/// cannot, because XCUITest cannot address an individual SwiftUI `Text` link).
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
        app.launch()
        let scenario = try ScenarioLoader.load(id: id, searchURL: Self.scenariosURL)
        do {
            try ScenarioRunner(registry: Page.ScenarioRegistry(app: app)).run(scenario)
        } catch {
            XCTFail("\(error)", file: file, line: line)
        }
    }

    /// The repo-root `scenarios/` directory, resolved from this source file's location:
    /// .../cupertino-desktop/Apps/CupertinoMobileUIKit/UITests/<this file>.
    private static let scenariosURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // UITests
        .deletingLastPathComponent() // CupertinoMobileUIKit
        .deletingLastPathComponent() // Apps
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("scenarios", isDirectory: true)
}
