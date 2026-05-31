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
    private let backendMode: Model.BackendMode

    init() {
        let mode = Self.effectiveMode()
        let backend = Self.makeBackend(mode: mode)
        backendMode = mode
        _frameworks = State(initialValue: Feature.FrameworkBrowser.ViewModel(backend: backend))
        _search = State(initialValue: Feature.Search.ViewModel(backend: backend))
    }

    /// The backend the app is actually using: `Model.AppSettings` (default `.mcpSubprocess`,
    /// the stdio `cupertino serve` route), except `-uitest-mock` forces `.embedded` so UI
    /// tests run offline.
    private static func effectiveMode() -> Model.BackendMode {
        if ProcessInfo.processInfo.arguments.contains("-uitest-mock") {
            return .embedded
        }
        return Model.AppSettings.load().backend
    }

    /// `.mcpSubprocess` spawns the local `cupertino serve`; `.embedded` reads the in-process
    /// corpus (App-Sandbox-safe), served by the bundled mock until `CupertinoDataEngine` ships.
    private static func makeBackend(mode: Model.BackendMode) -> any Backend.Documentation {
        switch mode {
        case .mcpSubprocess: MacBackend.live()
        case .embedded: MobileBackend.mock()
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

        // A menu-bar status item showing the active connection type (its SF Symbol), so the
        // backend in use is visible at a glance (HIG: symbols belong in menu-bar items).
        MenuBarExtra(backendMode.label, systemImage: backendMode.systemImage) {
            Text("Connection: \(backendMode.label)")
            Text("Edit settings.json to change the backend.")
        }
    }
}
