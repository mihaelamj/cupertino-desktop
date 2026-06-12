import XCTest

@MainActor
enum DesktopSwiftUITestLauncher {
    static func launch(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-mock", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        ensureWindow(for: app, file: file, line: line)
        return app
    }

    private static func ensureWindow(
        for app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) {
        app.activate()
        if app.windows.firstMatch.waitForExistence(timeout: 15) {
            return
        }

        let fileMenu = app.menuBars.menuBarItems["File"].firstMatch
        if fileMenu.waitForExistence(timeout: 2) {
            fileMenu.click()
            let newWindow = fileMenu.menus.menuItems["New Window"].firstMatch
            if newWindow.waitForExistence(timeout: 2), newWindow.isEnabled {
                newWindow.click()
            }
        }

        if !app.windows.firstMatch.waitForExistence(timeout: 5) {
            XCTFail("CupertinoDesktopSwiftUI did not expose a window.\n\(app.debugDescription)", file: file, line: line)
        }
    }
}
