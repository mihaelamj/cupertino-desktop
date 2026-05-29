import DesktopModels
import DesktopUI
import SearchFeature
import SearchSwiftUI
import SwiftUI

public extension CupertinoDesktop.UI {
    /// The SwiftUI combined flow: assembles the SwiftUI screens into a
    /// `NavigationSplitView` root, hosted in a controller behind the shared
    /// `Flow` seam so the app consumes it identically to the AppKit flow.
    @MainActor
    struct SwiftUIFlow: CupertinoDesktop.UI.Flow {
        public init() {}

        public func makeRootController() -> CupertinoDesktop.UI.ViewController {
            NSHostingController(rootView: RootView())
        }
    }
}
