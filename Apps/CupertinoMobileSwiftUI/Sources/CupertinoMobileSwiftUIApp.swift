import AppCore
import FrameworkBrowserFeature
import MobileBackendImpl
import SearchFeature
import ShellSwiftUI
import SwiftUI

/// App targets contain entry points only; all views live in packages
/// (docs/rules/package-structure.md). This composition root creates one backend and
/// injects it into the feature view models, then composes the shared SwiftUI shells
/// into a tabbed root: the framework browser (`UI.RootExperience`, a
/// `NavigationSplitView` that adapts iPhone/iPad) and the search screen
/// (`UI.SearchView`, which exposes every `searchDocs` option over every database).
///
/// The backend is `MobileBackend.mock()` for now: the in-process embedded adapter over
/// a captured real-data corpus, because the real `CupertinoDataEngine` is not published
/// yet. Swap to `MobileBackend.live(dataSource:)` over the real engine when it ships, a
/// one-line change here.
@main
struct CupertinoMobileSwiftUIApp: App {
    @State private var model = UI.RootModel()
    @State private var frameworks: Feature.FrameworkBrowser.ViewModel
    @State private var search: Feature.Search.ViewModel
    private let experience = UI.LiveRootExperience()

    init() {
        let backend = MobileBackend.mock()
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
    }
}
