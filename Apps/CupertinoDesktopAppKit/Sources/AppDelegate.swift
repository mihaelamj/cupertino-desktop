import AppCore
import AppKit
import FrameworkBrowserFeature
import MacBackendImpl
import SearchFeature
import ShellAppKit

/// Entry point only; the window's content comes from the AppKit shell package,
/// consumed through the shared-shape `RootExperience` protocol. This composition
/// root is the one place the live backend is created (`MacBackend.live()`). One
/// backend instance is injected into both feature view models, then the shared
/// shells are composed into a tabbed window: the framework browser
/// (`RootExperience`) and the search screen (`UI.SearchViewController`), matching
/// the other three app targets.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = UI.RootModel()
    private let experience: any UI.RootExperience = UI.LiveRootExperience()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        installMainMenu()

        let backend = MacBackend.live()
        let frameworks = Feature.FrameworkBrowser.ViewModel(backend: backend)
        let search = Feature.Search.ViewModel(backend: backend)

        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        let browser = NSTabViewItem(viewController: experience.makeRoot(model: model, frameworks: frameworks))
        browser.label = "Frameworks"
        browser.image = NSImage(systemSymbolName: "books.vertical", accessibilityDescription: "Frameworks")
        let searchTab = NSTabViewItem(viewController: UI.makeSearch(model: search))
        searchTab.label = "Search"
        searchTab.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        tabs.addTabViewItem(browser)
        tabs.addTabViewItem(searchTab)

        let window = NSWindow(contentViewController: tabs)
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
