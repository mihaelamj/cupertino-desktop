import AppKit
import AppKitFlow
import DesktopUI

/// Entry point only. The app injects the AppKit flow and consumes it through the
/// shared CupertinoDesktop.UI.Flow protocol, identically to the SwiftUI app.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private let flow: any CupertinoDesktop.UI.Flow = CupertinoDesktop.UI.AppKitFlow()

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        installMainMenu()

        let window = NSWindow(contentViewController: flow.makeRootController())
        window.setContentSize(NSSize(width: 1000, height: 640))
        window.title = "Cupertino Desktop"
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        let appName = ProcessInfo.processInfo.processName
        appMenu.addItem(
            withTitle: "Quit \(appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q",
        )
        appMenuItem.submenu = appMenu

        NSApp.mainMenu = mainMenu
    }
}
