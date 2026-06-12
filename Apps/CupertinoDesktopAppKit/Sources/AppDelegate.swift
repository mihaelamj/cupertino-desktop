import AppCore
import AppKit
import AppModels
import BackendAPI
import FrameworkBrowserFeature
import MacBackendImpl
import MobileBackendImpl
import SearchFeature
import ShellAppKit

/// Entry point only; the window's content comes from the AppKit shell package,
/// consumed through the shared-shape `RootExperience` protocol. This composition
/// root is the one place the live backend is created (`MacBackend.live()`). One
/// backend instance is injected into both feature view models, then the shared
/// shells are composed into a tabbed window: the framework browser
/// (`RootExperience`) and the search screen (`UI.SearchViewController`), matching
/// the other three app targets.
///
/// Under the `-uitest-mock` launch argument the deterministic embedded corpus is
/// injected instead of the live subprocess, so UI tests run offline and reproducibly
/// (the GUI/test launch environment cannot reach the `cupertino serve` binary). The UI
/// is identical either way; only the injected `Backend.Documentation` differs.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = UI.RootModel()
    private let experience: any UI.RootExperience = UI.LiveRootExperience()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        installMainMenu()

        let mode = Self.effectiveMode()
        let backend = Self.makeBackend(mode: mode)
        let frameworks = Feature.FrameworkBrowser.ViewModel(backend: backend)
        let search = Feature.Search.ViewModel(backend: backend)

        let tabs = MainTabViewController()
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
        let size = NSSize(width: 1000, height: 640)
        window.setContentSize(size)
        window.title = "Cupertino Desktop"
        window.addTitlebarAccessoryViewController(ConnectionStatusAccessory(frameworks: frameworks, mode: mode))
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }

    /// The backend the app is actually using: `Model.AppSettings` (default `.mcpSubprocess`,
    /// the stdio `cupertino serve` route), except `-uitest-mock` forces `.embedded` so UI
    /// tests run offline.
    private static func effectiveMode() -> Model.BackendMode {
        if ProcessInfo.processInfo.arguments.contains("-uitest-mock") {
            return .embedded
        }
        return Model.AppSettings.load().backend
    }

    /// `.mcpSubprocess` spawns the local `cupertino serve`; `.embedded` is the deterministic
    /// UI-test mock. Mobile real-catalog composition is kept in the mobile app targets.
    private static func makeBackend(mode: Model.BackendMode) -> any Backend.Documentation {
        switch mode {
        case .mcpSubprocess: MacBackend.live()
        case .embedded: MobileBackend.mock()
        }
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

@MainActor
private final class MainTabViewController: NSTabViewController {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
            if event.charactersIgnoringModifiers == "f" {
                selectedTabViewItemIndex = 1
                if let window = view.window {
                    if let searchField = tabViewItems[1].viewController?.view.findSearchField() {
                        window.makeFirstResponder(searchField)
                    }
                }
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor
private extension NSView {
    func findSearchField() -> NSSearchField? {
        if let searchField = self as? NSSearchField {
            return searchField
        }
        for subview in subviews {
            if let found = subview.findSearchField() {
                return found
            }
        }
        return nil
    }
}
