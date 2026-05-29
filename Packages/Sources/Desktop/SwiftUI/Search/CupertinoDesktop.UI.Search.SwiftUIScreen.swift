import DesktopModels
import DesktopUI
import SearchFeature
import SwiftUI

public extension CupertinoDesktop.UI.Search {
    /// SwiftUI conformer of the shared `Search.Providing` seam. Hosts the
    /// SwiftUI view in an `NSHostingController` so it returns the same
    /// `ViewController` type the AppKit conformer does.
    @MainActor
    struct SwiftUIScreen: CupertinoDesktop.UI.Search.Providing {
        public init() {}

        public func makeController(
            model: CupertinoDesktop.Feature.Search.Model,
        ) -> CupertinoDesktop.UI.ViewController {
            NSHostingController(rootView: SwiftUIView(model: model))
        }
    }
}
