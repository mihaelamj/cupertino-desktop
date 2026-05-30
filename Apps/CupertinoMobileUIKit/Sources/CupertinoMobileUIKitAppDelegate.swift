import AppCore
import FrameworkBrowserFeature
import MobileBackendImpl
import ShellUIKit
import UIKit

/// App targets contain entry points only; all views live in packages
/// (docs/rules/package-structure.md). This composition root creates the backend,
/// injects it into the feature view models, and hands them to the shared UIKit
/// shell (`UI.RootExperience`). It is the UIKit counterpart to the SwiftUI mobile
/// app: the same backend and the same `Feature.FrameworkBrowser.ViewModel`, so the
/// two frameworks can be compared on one seam (per docs/DESIGN.md and the dual-UI
/// approach used on macOS). The shell is a `UISplitViewController`, which adapts to
/// iPhone (one pane, navigation stack) and iPad (multi-column) per the HIG.
///
/// The backend is `MobileBackend.mock()` for now (see CupertinoMobileSwiftUI): the
/// embedded adapter over a hand-written `Search.DocumentReading` stand-in, because
/// the real `CupertinoDataEngine` is not published yet. Swap to
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
        let frameworks = Feature.FrameworkBrowser.ViewModel(backend: MobileBackend.mock())
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = experience.makeRoot(model: model, frameworks: frameworks)
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
