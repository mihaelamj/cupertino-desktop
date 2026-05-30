import AppCore
import FrameworkBrowserFeature
import MobileBackendImpl
import ShellSwiftUI
import SwiftUI

/// App targets contain entry points only; all views live in packages
/// (docs/rules/package-structure.md). This composition root creates the backend and
/// injects it into the feature view models, then hands them to the shared SwiftUI
/// shell (`UI.RootExperience`), the same shell the macOS SwiftUI app uses, so
/// iPhone, iPad, and macOS share one view layer. The shell's `NavigationSplitView`
/// adapts across size classes: columns on iPad regular width, a navigation stack on
/// iPhone compact width.
///
/// The backend is `MobileBackend.mock()` for now: the in-process embedded adapter
/// over a hand-written `Search.DocumentReading` stand-in, because the real
/// `CupertinoDataEngine` is not published yet. Swap to
/// `MobileBackend.live(dataSource:)` over the real engine when it ships, a one-line
/// change here.
@main
struct CupertinoMobileSwiftUIApp: App {
    @State private var model = UI.RootModel()
    @State private var frameworks = Feature.FrameworkBrowser.ViewModel(backend: MobileBackend.mock())
    private let experience = UI.LiveRootExperience()

    var body: some Scene {
        WindowGroup {
            experience.makeRoot(model: model, frameworks: frameworks)
        }
    }
}
