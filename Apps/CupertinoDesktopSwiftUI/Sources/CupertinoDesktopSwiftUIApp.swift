import AppCore
import ShellSwiftUI
import SwiftUI

/// App targets contain entry points only; all views live in packages
/// (docs/rules/package-structure.md). The root comes from the SwiftUI shell
/// package, consumed through the shared-shape `RootExperience` protocol.
@main
struct CupertinoDesktopSwiftUIApp: App {
    @State private var model = UI.RootModel()
    private let experience = UI.LiveRootExperience()

    var body: some Scene {
        WindowGroup {
            experience.makeRoot(model: model)
        }
        .windowStyle(.titleBar)
    }
}
