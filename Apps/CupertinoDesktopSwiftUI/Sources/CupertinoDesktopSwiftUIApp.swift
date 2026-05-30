import AppCore
import FrameworkBrowserFeature
import MacBackendImpl
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
@main
struct CupertinoDesktopSwiftUIApp: App {
    @State private var model = UI.RootModel()
    @State private var frameworks: Feature.FrameworkBrowser.ViewModel
    @State private var search: Feature.Search.ViewModel
    private let experience = UI.LiveRootExperience()

    init() {
        let backend = MacBackend.live()
        _frameworks = State(initialValue: Feature.FrameworkBrowser.ViewModel(backend: backend))
        _search = State(initialValue: Feature.Search.ViewModel(backend: backend))
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
