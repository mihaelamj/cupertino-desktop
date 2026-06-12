import AppCore
import BackendAPI
import CatalogStoreAPI
import DevelopmentCatalogStore
import FrameworkBrowserFeature
import MobileBackendImpl
import SearchFeature
import ShellUIKit
import UIKit

/// App targets contain entry points only; all views live in packages
/// (docs/rules/package-structure.md). This composition root creates one backend,
/// injects it into both feature view models, and composes the shared UIKit shells
/// into a tab bar: the framework browser (`UI.RootExperience`, a
/// `UISplitViewController`) and the search screen (`UI.SearchViewController`). It is
/// the UIKit counterpart to the SwiftUI mobile app, the same backend and the same
/// view models, so the two frameworks can be compared on one seam (docs/DESIGN.md).
///
/// The backend defaults to `MobileBackend.mock()` for no-catalog simulator work. Set
/// `CUPERTINO_MOBILE_USE_DEV_CATALOG=1` and optionally `CUPERTINO_MOBILE_DEV_CATALOG`
/// to exercise the real embedded engine through a development catalog.
@main
final class CupertinoMobileUIKitAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private let model = UI.RootModel()
    private let experience = UI.LiveRootExperience()

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil,
    ) -> Bool {
        let backend = Self.makeBackend()
        let frameworks = Feature.FrameworkBrowser.ViewModel(backend: backend)
        let search = Feature.Search.ViewModel(backend: backend)

        let browser: UIViewController
        if UIDevice.current.userInterfaceIdiom == .phone {
            let sidebar = UI.makeFrameworkBrowser(model: model, frameworks: frameworks)
            sidebar.title = "Cupertino (UIKit)"
            browser = UINavigationController(rootViewController: sidebar)
        } else {
            browser = experience.makeRoot(model: model, frameworks: frameworks)
        }
        browser.tabBarItem = UITabBarItem(title: "Frameworks", image: UIImage(systemName: "books.vertical"), tag: 0)

        let searchNavigation = UINavigationController(rootViewController: UI.makeSearch(model: search))
        searchNavigation.tabBarItem = UITabBarItem(tabBarSystemItem: .search, tag: 1)

        let tabs = MainTabBarController()
        tabs.viewControllers = [browser, searchNavigation]

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = tabs
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    private static func makeBackend() -> any Backend.Documentation {
        let environment = ProcessInfo.processInfo.environment
        let devCatalogURL = Catalog.DevelopmentStore.corpusURL(
            environment: environment,
            homeDirectory: catalogHomeDirectory(),
        )

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: devCatalogURL.path, isDirectory: &isDirectory)

        let isTesting = environment["CUPERTINO_UI_TESTING"] == "1"

        if environment[Catalog.DevelopmentStore.mobileOptInEnvironmentKey] == "1" || (!isTesting && exists && isDirectory.boolValue) {
            return MobileBackend.deferred(catalogStore: Catalog.DevelopmentStore(corpusURL: devCatalogURL))
        } else {
            return MobileBackend.mock()
        }
    }

    private static func catalogHomeDirectory() -> URL {
        #if targetEnvironment(simulator)
            if let hostHome = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] {
                return URL(fileURLWithPath: hostHome)
            }
        #endif
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }
}

@MainActor
private final class MainTabBarController: UITabBarController {
    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(
                title: "Find...",
                image: nil,
                action: #selector(focusSearch),
                input: "f",
                modifierFlags: .command,
                propertyList: nil,
                alternates: [],
                discoverabilityTitle: "Find",
                state: .off,
            ),
        ]
    }

    @objc private func focusSearch() {
        selectedIndex = 1
        if let searchField = viewControllers?[1].view.findSearchTextField() {
            searchField.becomeFirstResponder()
        }
    }
}

@MainActor
private extension UIView {
    func findSearchTextField() -> UISearchTextField? {
        if let searchField = self as? UISearchTextField {
            return searchField
        }
        for subview in subviews {
            if let found = subview.findSearchTextField() {
                return found
            }
        }
        return nil
    }
}
