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

        let browser = experience.makeRoot(model: model, frameworks: frameworks)
        browser.tabBarItem = UITabBarItem(title: "Frameworks", image: UIImage(systemName: "books.vertical"), tag: 0)

        let searchNavigation = UINavigationController(rootViewController: UI.makeSearch(model: search))
        searchNavigation.tabBarItem = UITabBarItem(tabBarSystemItem: .search, tag: 1)

        let tabs = UITabBarController()
        tabs.viewControllers = [browser, searchNavigation]

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = tabs
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    private static func makeBackend() -> any Backend.Documentation {
        guard ProcessInfo.processInfo.environment[Catalog.DevelopmentStore.mobileOptInEnvironmentKey] == "1" else {
            return MobileBackend.mock()
        }
        return MobileBackend.deferred(catalogStore: Catalog.DevelopmentStore(corpusURL: Catalog.DevelopmentStore.corpusURL(
            environment: ProcessInfo.processInfo.environment,
            homeDirectory: catalogHomeDirectory(),
        )))
    }

    private static func catalogHomeDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }
}
