import DesktopUI
import SwiftUI
import SwiftUIFlow

/// Entry point only. The app injects the SwiftUI flow and consumes it through the
/// shared CupertinoDesktop.UI.Flow protocol, identically to how the AppKit app
/// consumes AppKitFlow (docs/rules/package-structure.md).
@main
struct CupertinoDesktopSwiftUIApp: App {
    private let flow: any CupertinoDesktop.UI.Flow = CupertinoDesktop.UI.SwiftUIFlow()

    var body: some Scene {
        WindowGroup {
            CupertinoDesktop.UI.ControllerView(flow.makeRootController())
        }
    }
}
