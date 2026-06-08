import AppCore
import XCTest

public extension Page {
    /// Base page object: the recurring XCUITest plumbing (locate by identifier, wait, tap,
    /// assert, screenshot) so concrete pages only declare their screen's actions. Elements
    /// are matched by accessibility identifier across any element type, which keeps every
    /// page cross-platform (a SwiftUI view, a UIKit control, and an AppKit control with the
    /// same identifier all resolve the same way). Methods are `open` for per-app overrides.
    @MainActor
    open class Base {
        public let app: XCUIApplication

        public init(app: XCUIApplication) {
            self.app = app
        }

        /// Locate an element by accessibility identifier, any type (cross-platform).
        open func element(_ identifier: String) -> XCUIElement {
            app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        }

        @discardableResult
        open func waitForElement(
            _ identifier: String,
            timeout: TimeInterval = 10,
            file: StaticString = #filePath,
            line: UInt = #line,
        ) -> XCUIElement {
            let element = element(identifier)
            if !element.waitForExistence(timeout: timeout) {
                XCTFail("Element '\(identifier)' did not appear within \(timeout)s", file: file, line: line)
            }
            return element
        }

        open func tap(_ identifier: String, timeout: TimeInterval = 5) {
            let element = waitForElement(identifier, timeout: timeout)
            scrollToHittable(element, target: identifier)
            element.tap()
        }

        open func assertExists(
            _ identifier: String,
            timeout: TimeInterval = 10,
            file: StaticString = #filePath,
            line: UInt = #line,
        ) {
            let exists = element(identifier).waitForExistence(timeout: timeout)
            if !exists {
                XCTFail(
                    "Element '\(identifier)' should exist.\n\(app.debugDescription)",
                    file: file,
                    line: line,
                )
                return
            }
        }

        open func assertNotExists(
            _ identifier: String,
            file: StaticString = #filePath,
            line: UInt = #line,
        ) {
            XCTAssertFalse(element(identifier).exists, "Element '\(identifier)' should not exist", file: file, line: line)
        }

        open func takeScreenshot(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            XCTContext.runActivity(named: "Screenshot: \(name)") { $0.add(attachment) }
        }

        private func scrollToHittable(_ element: XCUIElement, target: String, maxSwipes: Int = 8) {
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
        }

        private func scrollSurface(for target: String) -> XCUIElement {
            if target.hasPrefix("framework_row_") {
                let sidebar = element(UI.AccessibilityID.FrameworkBrowser.sidebar)
                if sidebar.exists {
                    return sidebar
                }
            }
            return app
        }
    }
}
