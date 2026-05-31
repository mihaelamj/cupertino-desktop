import AppCore
import AppModels
import BackendAPI
import FrameworkBrowserFeature
import MacBackendImpl
import MobileBackendImpl
import SearchFeature
import ShellSwiftUI
import SwiftUI

/// App targets contain entry points only; all views live in packages
/// (docs/rules/package-structure.md). This composition root is the one place the
/// live backend is created (`MacBackend.live()`, the local `cupertino serve`
/// route). One backend instance is injected into both feature view models, then
/// the shared shells are composed into a tabbed root: the framework browser
/// (`RootExperience`, a `NavigationSplitView`) and the search screen
/// (`UI.SearchView`, which exposes every `searchDocs` option over every database),
/// matching the mobile SwiftUI app.
///
/// Under the `-uitest-mock` launch argument the deterministic embedded corpus is
/// injected instead of the live subprocess, so UI tests run offline and reproducibly
/// (the GUI/test launch environment cannot reach the `cupertino serve` binary). The UI
/// is identical either way; only the injected `Backend.Documentation` differs.
@main
struct CupertinoDesktopSwiftUIApp: App {
    @State private var model = UI.RootModel()
    @State private var frameworks: Feature.FrameworkBrowser.ViewModel
    @State private var search: Feature.Search.ViewModel
    private let experience = UI.LiveRootExperience()

    init() {
        let backend = Self.makeBackend()
        _frameworks = State(initialValue: Feature.FrameworkBrowser.ViewModel(backend: backend))
        _search = State(initialValue: Feature.Search.ViewModel(backend: backend))
    }

    /// Choose the backend from `Model.AppSettings` (default `.mcpSubprocess`, the stdio
    /// `cupertino serve` route). `-uitest-mock` forces the embedded corpus so UI tests run
    /// offline. `.embedded` is the App-Sandbox-safe in-process path; until the real
    /// `CupertinoDataEngine` ships it is served by the bundled mock corpus.
    private static func makeBackend() -> any Backend.Documentation {
        if ProcessInfo.processInfo.arguments.contains("-uitest-mock") {
            return MobileBackend.mock()
        }
        switch Model.AppSettings.load().backend {
        case .mcpSubprocess: return MacBackend.live()
        case .embedded: return MobileBackend.mock()
        }
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                experience.makeRoot(model: model, frameworks: frameworks)
                    .tabItem { Label("Frameworks", systemImage: "books.vertical") }
                UI.SearchView(model: search)
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
            }
        }
        .windowStyle(.titleBar)
    }
}
