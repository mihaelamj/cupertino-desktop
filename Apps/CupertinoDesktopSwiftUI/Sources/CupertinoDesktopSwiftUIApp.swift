import AppCore
import FrameworkBrowserFeature
import MacBackendImpl
import ShellSwiftUI
import SwiftUI

/// App targets contain entry points only; all views live in packages
/// (docs/rules/package-structure.md). This composition root is the one place the
/// live backend is created (`MacBackend.live()`, the local `cupertino serve`
/// route) and injected into the feature view models, which the SwiftUI shell binds
/// through the shared-shape `RootExperience` protocol.
@main
struct CupertinoDesktopSwiftUIApp: App {
    @State private var model = UI.RootModel()
    @State private var frameworks = Feature.FrameworkBrowser.ViewModel(backend: MacBackend.live())
    private let experience = UI.LiveRootExperience()

    var body: some Scene {
        WindowGroup {
            experience.makeRoot(model: model, frameworks: frameworks)
        }
        .windowStyle(.titleBar)
    }
}
