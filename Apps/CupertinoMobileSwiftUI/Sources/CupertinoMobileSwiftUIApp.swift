import AppCore
import BackendAPI
import CatalogStoreAPI
import DevelopmentCatalogStore
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
/// (`UI.SearchView`, which exposes every `searchDocs` option over every source).
///
/// The backend defaults to `MobileBackend.mock()` for no-catalog simulator work. Set
/// `CUPERTINO_MOBILE_USE_DEV_CATALOG=1` and optionally `CUPERTINO_MOBILE_DEV_CATALOG`
/// to exercise the real embedded engine through a development catalog.
@main
struct CupertinoMobileSwiftUIApp: App {
    @State private var model = UI.RootModel()
    @State private var frameworks: Feature.FrameworkBrowser.ViewModel
    @State private var search: Feature.Search.ViewModel
    private let experience = UI.LiveRootExperience()

    init() {
        let backend = Self.makeBackend()
        _frameworks = State(initialValue: Feature.FrameworkBrowser.ViewModel(backend: backend))
        _search = State(initialValue: Feature.Search.ViewModel(backend: backend))
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
