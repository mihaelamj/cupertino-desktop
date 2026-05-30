import FlowSpec
import XCTest

public extension Page {
    /// The Swift runner for FlowSpec scenarios: a `StepRegistry` that turns each
    /// `{ verb, target, arg }` into an XCUI action, matching elements by accessibility
    /// identifier so the same scenario drives the SwiftUI, AppKit, and UIKit apps. Throws
    /// `StepRegistryError` (not `XCTFail`) so the `ScenarioRunner` reports which step failed.
    @MainActor
    final class ScenarioRegistry: StepRegistry {
        private let app: XCUIApplication
        private let defaultTimeout: TimeInterval

        public init(app: XCUIApplication, defaultTimeout: TimeInterval = 15) {
            self.app = app
            self.defaultTimeout = defaultTimeout
        }

        private func element(_ identifier: String) -> XCUIElement {
            app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        }

        public func execute(_ step: Step) throws {
            switch step.verb {
            case .open, .tap:
                let element = try require(step)
                element.tap()
            case .type:
                let element = try require(step)
                element.tap()
                element.typeText(step.arg ?? "")
            case .swipe:
                let element = try require(step)
                switch step.arg {
                case "down": element.swipeDown()
                case "left": element.swipeLeft()
                case "right": element.swipeRight()
                default: element.swipeUp()
                }
            case .wait, .assert:
                let timeout = step.arg.flatMap(TimeInterval.init) ?? defaultTimeout
                if !element(step.target).waitForExistence(timeout: timeout) {
                    throw StepRegistryError.stepFailed(key: step.key, reason: "element `\(step.target)` did not appear")
                }
            }
        }

        /// Wait for the step's element and return it, or throw a failure naming the target.
        private func require(_ step: Step) throws -> XCUIElement {
            let element = element(step.target)
            guard element.waitForExistence(timeout: defaultTimeout) else {
                throw StepRegistryError.stepFailed(key: step.key, reason: "element `\(step.target)` not found")
            }
            return element
        }
    }
}
