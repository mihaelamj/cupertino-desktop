import AppCore
import PresentationBridge

#if canImport(UIKit)
    import UIKit

    public extension UI {
        /// The UIKit shell-root contract. Parallel to the SwiftUI and AppKit shells of
        /// the same qualified name and shape; this one vends a `UIViewController`. The
        /// UIKit app target consumes its conformer through this protocol.
        ///
        /// Same shape as the other shells: the app composition root builds the feature
        /// view models and hands them in. One explicit parameter today; a bundle is the
        /// abstraction to extract at the second feature (docs/DESIGN.md).
        @MainActor
        protocol RootExperience {
            func makeRoot(model: RootModel, frameworks: any Presentation.FrameworkBrowserViewModelProtocol) -> UIViewController
        }
    }
#endif
