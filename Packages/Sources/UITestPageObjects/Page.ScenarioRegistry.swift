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
                scrollToHittable(element)
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
                // Match by accessibility identifier first, then fall back to a visible
                // static-text or link label, so a scenario can assert a content-unavailable
                // view by its title (e.g. "Could not load document") the same way it asserts
                // an identifier. The label fallback is checked only if the identifier wait
                // fails, so identifier asserts keep the full timeout.
                let found = element(step.target).waitForExistence(timeout: timeout)
                    || app.staticTexts[step.target].firstMatch.waitForExistence(timeout: timeout)
                    || app.links[step.target].firstMatch.exists
                if !found {
                    throw StepRegistryError.stepFailed(key: step.key, reason: "element `\(step.target)` did not appear")
                }
            }
        }

        /// Locate the step's target: first by accessibility identifier, then (for
        /// in-document links and labels, which carry no identifier) by link or static-text
        /// label. This is what lets a scenario tap a "Mentioned in" link by its text.
        private func locate(_ target: String) -> XCUIElement {
            let byIdentifier = element(target)
            if byIdentifier.exists { return byIdentifier }
            // A label can legitimately repeat (e.g. the same link text twice in one
            // document), so resolve to the first match rather than the subscript's
            // unique-or-throw element.
            let link = app.links.matching(identifier: target).firstMatch
            if link.exists { return link }
            return app.staticTexts.matching(identifier: target).firstMatch
        }

        /// Wait for the step's element and return it, or throw a failure naming the target.
        private func require(_ step: Step) throws -> XCUIElement {
            let element = locate(step.target)
            guard element.waitForExistence(timeout: defaultTimeout) else {
                throw StepRegistryError.stepFailed(key: step.key, reason: "element `\(step.target)` not found")
            }
            return element
        }

        /// Scroll the element into a hittable position (links can sit below the fold).
        private func scrollToHittable(_ element: XCUIElement, maxSwipes: Int = 6) {
            var swipes = 0
            while !element.isHittable, swipes < maxSwipes {
                app.swipeUp()
                swipes += 1
            }
        }
    }
}
