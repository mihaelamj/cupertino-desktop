import AppCore
import ShellSwiftUI
import SwiftUI

/// App targets contain entry points only; all views live in packages
/// (docs/rules/package-structure.md). The root comes from the SwiftUI shell
/// package, the same UI.RootExperience seam the macOS SwiftUI app uses, so iOS and
/// macOS share one shell.
@main
struct CupertinoMobileApp: App {
    @State private var model = UI.RootModel()
    private let experience = UI.LiveRootExperience()

    var body: some Scene {
        WindowGroup {
            experience.makeRoot(model: model)
        }
    }
}
