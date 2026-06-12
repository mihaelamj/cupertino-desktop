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

        // MARK: - Base Element Lookup

        open func element(_ identifier: String) -> XCUIElement {
            if identifier.hasPrefix("framework_row_") ||
               identifier.hasPrefix("source_row_") ||
               identifier == UI.AccessibilityID.FrameworkBrowser.searchField ||
               identifier == UI.AccessibilityID.FrameworkBrowser.sortButton {
                let sidebars = app.descendants(matching: .any).matching(identifier: UI.AccessibilityID.FrameworkBrowser.sidebar).allElementsBoundByIndex
                for sidebar in sidebars where sidebar.exists && sidebar.frame.width > 0 && sidebar.frame.height > 0 {
                    let matches = sidebar.descendants(matching: .any).matching(identifier: identifier).allElementsBoundByIndex
                    if let visible = matches.first(where: { $0.exists && $0.frame.width > 0 && $0.frame.height > 0 }) {
                        return visible
                    }
                }
            }
            let matches = app.descendants(matching: .any).matching(identifier: identifier).allElementsBoundByIndex
            if let visible = matches.first(where: { $0.exists && $0.frame.width > 0 && $0.frame.height > 0 }) {
                return visible
            }
            return app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        }

        // MARK: - Common Wait Methods

        /// Wait for an element to exist by its identifier.
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

        /// Wait for an element to exist
        @discardableResult
        open func waitForElement(
            _ element: XCUIElement,
            timeout: TimeInterval = 10,
            file: StaticString = #filePath,
            line: UInt = #line,
        ) -> Bool {
            let exists = element.waitForExistence(timeout: timeout)
            if !exists {
                XCTFail("Element \(element) did not appear within \(timeout) seconds", file: file, line: line)
            }
            return exists
        }

        /// Wait for an element to disappear
        @discardableResult
        open func waitForElementToDisappear(
            _ element: XCUIElement,
            timeout: TimeInterval = 10,
            file: StaticString = #filePath,
            line: UInt = #line,
        ) -> Bool {
            let predicate = NSPredicate(format: "exists == false")
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
            let result = XCTWaiter().wait(for: [expectation], timeout: timeout)

            if result != .completed {
                XCTFail("Element \(element) did not disappear within \(timeout) seconds", file: file, line: line)
                return false
            }
            return true
        }

        /// Wait for an element by identifier with element type
        @discardableResult
        open func waitForElementByIdentifier(
            _ identifier: String,
            type: XCUIElement.ElementType = .any,
            timeout: TimeInterval = 10,
            file: StaticString = #filePath,
            line: UInt = #line,
        ) -> XCUIElement {
            let element = type == .any ? app.descendants(matching: .any)[identifier] : app.descendants(matching: type)[identifier]
            _ = waitForElement(element, timeout: timeout, file: file, line: line)
            return element
        }

        // MARK: - Common Tap Methods

        /// Tap an element after waiting for it to exist
        open func tapElement(_ element: XCUIElement, timeout: TimeInterval = 5) {
            _ = waitForElement(element, timeout: timeout)
            element.performTap()
        }

        /// Tap an element by identifier
        open func tapElementByIdentifier(
            _ identifier: String,
            type: XCUIElement.ElementType = .any,
            timeout: TimeInterval = 5,
        ) {
            let element = waitForElementByIdentifier(identifier, type: type, timeout: timeout)
            element.performTap()
        }

        open func tap(_ identifier: String, timeout: TimeInterval = 5) {
            let element = waitForElement(identifier, timeout: timeout)
            scrollToHittable(element, target: identifier)
            element.performTap()
        }

        // MARK: - Common Assertion Methods

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

        /// Assert element exists
        open func assertExists(
            _ element: XCUIElement,
            message: String? = nil,
            file: StaticString = #filePath,
            line: UInt = #line,
        ) {
            XCTAssertTrue(element.exists, message ?? "Element should exist", file: file, line: line)
        }

        /// Assert element does not exist
        open func assertNotExists(
            _ element: XCUIElement,
            message: String? = nil,
            file: StaticString = #filePath,
            line: UInt = #line,
        ) {
            XCTAssertFalse(element.exists, message ?? "Element should not exist", file: file, line: line)
        }

        open func assertNotExists(
            _ identifier: String,
            file: StaticString = #filePath,
            line: UInt = #line,
        ) {
            XCTAssertFalse(element(identifier).exists, "Element '\(identifier)' should not exist", file: file, line: line)
        }

        /// Assert element by identifier exists
        open func assertExistsByIdentifier(
            _ identifier: String,
            type: XCUIElement.ElementType = .any,
            message: String? = nil,
            file: StaticString = #filePath,
            line: UInt = #line,
        ) {
            let element = type == .any ? app.descendants(matching: .any)[identifier] : app.descendants(matching: type)[identifier]
            assertExists(element, message: message ?? "Element '\(identifier)' should exist", file: file, line: line)
        }

        // MARK: - Screenshot Helpers

        open func takeScreenshot(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            XCTContext.runActivity(named: "Screenshot: \(name)") { $0.add(attachment) }
        }

        /// Take and attach a screenshot with custom lifetime
        open func takeScreenshot(name: String, lifetime: XCTAttachment.Lifetime = .keepAlways) {
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = name
            attachment.lifetime = lifetime
            XCTContext.runActivity(named: "Screenshot: \(name)") { activity in
                activity.add(attachment)
            }
        }

        // MARK: - Scroll Helpers

        /// Scroll to find an element if not visible
        @discardableResult
        open func scrollToElement(
            _ element: XCUIElement,
            direction: ScrollDirection = .down,
            maxScrolls: Int = 5,
        ) -> Bool {
            #if os(macOS)
                return element.isHittable
            #else
                var scrollCount = 0
                while !element.isHittable, scrollCount < maxScrolls {
                    switch direction {
                    case .up:
                        app.swipeDown()
                    case .down:
                        app.swipeUp()
                    case .left:
                        app.swipeRight()
                    case .right:
                        app.swipeLeft()
                    }
                    scrollCount += 1
                }
                return element.isHittable
            #endif
        }

        /// Direction passed to ``scrollToElement(_:direction:maxScrolls:)``. Determines which
        /// swipe the helper uses to reveal off-screen content.
        public enum ScrollDirection {
            /// Reveal content above the current scroll position.
            case up
            /// Reveal content below the current scroll position.
            case down
            /// Reveal content to the left (for horizontal scrollers).
            case left
            /// Reveal content to the right.
            case right
        }

        /// Tap element with scroll support - scrolls to find element if not visible
        open func tapElementWithScroll(
            _ element: XCUIElement,
            direction: ScrollDirection = .down,
            timeout: TimeInterval = 5,
        ) {
            if !element.isHittable {
                _ = scrollToElement(element, direction: direction)
            }
            _ = waitForElement(element, timeout: timeout)
            element.performTap()
        }

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
                for sidebar in sidebars where sidebar.exists && sidebar.frame.width > 0 && sidebar.frame.height > 0 {
                    if sidebar.descendants(matching: .any).matching(identifier: target).firstMatch.exists {
                        return sidebar
                    }
                }
            }
            return app
        }

        // MARK: - Hierarchy Dump Assertions

        /// Asserts that no raw 22-char German IBAN (`DE` + 20 digits) appears
        /// anywhere in the app's accessibility hierarchy. Uses
        /// `app.debugDescription` (the canonical text dump of the entire tree)
        /// and regex-matches against it.
        open func verifyNoRawIBANInHierarchy(
            context: String,
            file: StaticString = #filePath,
            line: UInt = #line,
        ) {
            let dump = app.debugDescription
            let regex = try? NSRegularExpression(pattern: #"\bDE\d{20}\b"#)
            guard let regex else {
                XCTFail("IBAN regex failed to compile", file: file, line: line)
                return
            }
            let range = NSRange(dump.startIndex ..< dump.endIndex, in: dump)
            let matches = regex.matches(in: dump, range: range)
            if !matches.isEmpty {
                let hits = matches.prefix(3).compactMap { m -> String? in
                    Range(m.range, in: dump).map { String(dump[$0]) }
                }
                XCTFail(
                    "Raw IBAN leaked into the view hierarchy at \(context). Matches: \(hits)",
                    file: file,
                    line: line,
                )
            }
        }

        // MARK: - Flexible Element Finding

        /// Find element by identifier across multiple element types
        open func findElementByIdentifier(
            _ identifier: String,
            types: [XCUIElement.ElementType] = [.button, .staticText, .other, .any],
        ) -> XCUIElement? {
            for type in types {
                let element = app.descendants(matching: type)[identifier]
                if element.exists {
                    return element
                }
            }
            return nil
        }
    }
}

extension XCUIElement {
    @MainActor
    func performTap() {
        #if os(macOS)
            click()
        #else
            tap()
        #endif
    }
}
