import AppCore
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
            if identifier.hasPrefix("framework_row_") ||
               identifier.hasPrefix("source_row_") ||
               identifier == UI.AccessibilityID.FrameworkBrowser.searchField ||
               identifier == UI.AccessibilityID.FrameworkBrowser.sortButton {
                let sidebars = app.descendants(matching: .any).matching(identifier: UI.AccessibilityID.FrameworkBrowser.sidebar).allElementsBoundByIndex
                if let sidebar = sidebars.first(where: { $0.exists && $0.isHittable && $0.frame.width > 0 && $0.frame.height > 0 }) {
                    let matches = sidebar.descendants(matching: .any).matching(identifier: identifier).allElementsBoundByIndex
                    if let visible = matches.first(where: { $0.exists && $0.frame.width > 0 && $0.frame.height > 0 }) {
                        return visible
                    }
                }
            }
            if identifier == UI.AccessibilityID.FrameworkBrowser.searchField {
                let systemSearch = app.searchFields.firstMatch
                if systemSearch.exists {
                    return systemSearch
                }
            }
            let matches = app.descendants(matching: .any).matching(identifier: identifier).allElementsBoundByIndex
            if let visible = matches.first(where: { $0.exists && $0.frame.width > 0 && $0.frame.height > 0 }) {
                return visible
            }
            return app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        }

        public func execute(_ step: Step) throws {
            switch step.verb {
            case .open, .tap:
                let element = try require(step)
                scrollToHittable(element, target: step.target)
                element.performTap()

                if step.target.hasPrefix("framework_row_") {
                    let reader = self.element(UI.AccessibilityID.FrameworkBrowser.reader)
                    if !reader.exists {
                        let firstCell = app.descendants(matching: .any).matching(identifier: "document_cell").firstMatch
                        if firstCell.waitForExistence(timeout: 10) {
                            firstCell.performTap()
                        }
                    }
                }
            case .type:
                let element = try require(step)
                element.performTap()
                let text = step.arg ?? ""
                element.typeText(text)
                #if os(iOS)
                    if element.elementType == .searchField || step.target.contains("search") {
                        let searchButton = app.keyboards.buttons["Search"]
                        if searchButton.waitForExistence(timeout: 2), searchButton.isHittable {
                            searchButton.performTap()
                        } else {
                            let returnButton = app.keyboards.buttons["Return"]
                            if returnButton.exists, returnButton.isHittable {
                                returnButton.performTap()
                            }
                        }
                    }
                #endif
            case .swipe:
                let element = try require(step)
                switch step.arg {
                case "down": element.swipeDown()
                case "left": element.swipeLeft()
                case "right": element.swipeRight()
                default: element.swipeUp()
                }
            case .wait:
                let timeout = step.arg.flatMap(TimeInterval.init) ?? defaultTimeout
                let found = element(step.target).waitForExistence(timeout: timeout)
                    || app.staticTexts[step.target].firstMatch.waitForExistence(timeout: timeout)
                    || app.links[step.target].firstMatch.exists
                if !found {
                    throw StepRegistryError.stepFailed(key: step.key, reason: "element `\(step.target)` did not appear")
                }
            case .assert:
                if step.target == "no-raw-iban-in-hierarchy" {
                    Page.Base(app: app).verifyNoRawIBANInHierarchy(context: step.arg ?? "FlowSpec")
                    return
                }
                let timeout = step.arg.flatMap(TimeInterval.init) ?? defaultTimeout
                let found = element(step.target).waitForExistence(timeout: timeout)
                    || app.staticTexts[step.target].firstMatch.waitForExistence(timeout: timeout)
                    || app.links[step.target].firstMatch.exists
                if !found {
                    throw StepRegistryError.stepFailed(key: step.key, reason: "element `\(step.target)` did not appear")
                }
            case .request:
                // No-op stamp to keep cross-platform scenario files compatible,
                // similar to how mauintern handles web/HTTP actions on platforms that don't need them.
                break
            }
        }

        /// Locate the step's target: first by accessibility identifier, then (for
        /// in-document links and labels, which carry no identifier) by link or static-text
        /// label. This is what lets a scenario tap a "Mentioned in" link by its text.
        private func locate(_ target: String) -> XCUIElement {
            if target.hasPrefix("framework_row_") {
                let appleDocsRow = element(UI.AccessibilityID.FrameworkBrowser.sourceRow("appleDocs"))
                let targetElement = element(target)
                _ = appleDocsRow.waitForExistence(timeout: 5)
                if appleDocsRow.exists, !targetElement.exists {
                    appleDocsRow.performTap()
                }
            }

            let byIdentifier = element(target)
            if byIdentifier.waitForExistence(timeout: 0.5) { return byIdentifier }

            if target == UI.AccessibilityID.FrameworkBrowser.sortButton {
                return app.buttons["Sort"].firstMatch
            }
            if target == UI.AccessibilityID.FrameworkBrowser.sortByNameOption {
                let nameOption = app.buttons["Name"].firstMatch
                if nameOption.exists { return nameOption }
                return app.menuItems["Name"].firstMatch
            }
            if target == UI.AccessibilityID.FrameworkBrowser.sortByCountOption {
                let countOption = app.buttons["Count"].firstMatch
                if countOption.exists { return countOption }
                return app.menuItems["Count"].firstMatch
            }

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
        private func scrollToHittable(_ element: XCUIElement, target: String, maxSwipes: Int = 8) {
            #if os(macOS)
                // On macOS, elements are usually visible or scroll views handle it differently,
                // and swiping the app itself is not supported.
                return
            #else
                let surface = scrollSurface(for: target)
                var swipes = 0
                while !element.isHittable, swipes < maxSwipes {
                    if element.frame.midY < surface.frame.minY {
                        surface.swipeDown()
                    } else {
                        surface.swipeUp()
                    }
                    swipes += 1
                }
            #endif
        }

        private func scrollSurface(for target: String) -> XCUIElement {
            if target.hasPrefix("framework_row_") {
                let sidebars = app.descendants(matching: .any).matching(identifier: UI.AccessibilityID.FrameworkBrowser.sidebar).allElementsBoundByIndex
                if let activeSidebar = sidebars.first(where: { $0.exists && $0.isHittable && $0.frame.width > 0 && $0.frame.height > 0 }) {
                    return activeSidebar
                }
            }
            return app
        }
    }
}
