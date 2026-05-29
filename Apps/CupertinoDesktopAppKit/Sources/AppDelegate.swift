import AppKit
import DesktopCore
import ShellAppKit

// Entry point only; the window's content comes from the AppKit shell package,
// consumed through the shared-shape `RootExperience` protocol.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = UI.RootModel()
    private let experience: any UI.RootExperience = UI.LiveRootExperience()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        installMainMenu()

        let window = NSWindow(contentViewController: experience.makeRoot(model: model))
        window.setContentSize(NSSize(width: 1000, height: 640))
        window.title = "Cupertino Desktop"
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
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
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu

        NSApp.mainMenu = mainMenu
    }
}
