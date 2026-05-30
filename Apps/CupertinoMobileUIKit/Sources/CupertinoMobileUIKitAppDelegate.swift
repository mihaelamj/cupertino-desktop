import AppCore
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
/// The backend is `MobileBackend.mock()` for now (see CupertinoMobileSwiftUI): the
/// embedded adapter over a captured real-data corpus, because the real
/// `CupertinoDataEngine` is not published yet. Swap to
/// `MobileBackend.live(dataSource:)` over the real engine when it ships.
@main
final class CupertinoMobileUIKitAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private let model = UI.RootModel()
    private let experience = UI.LiveRootExperience()

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil,
    ) -> Bool {
        let backend = MobileBackend.mock()
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
}
