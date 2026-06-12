import AppCore
import PresentationBridge

#if canImport(SwiftUI)
    import SwiftUI

    public extension UI {
        /// The SwiftUI shell-root contract. Parallel to the AppKit shell's protocol
        /// of the same qualified name and shape; this one vends a SwiftUI `View`. The
        /// SwiftUI app target consumes its conformer through this protocol.
        ///
        /// The app composition root builds the feature view models (they own the
        /// injected backend) and hands them in. With one feature today this is a single
        /// explicit parameter; a bundle is the abstraction to extract once a second
        /// feature appears (docs/DESIGN.md, the parallel seam-discovery note).
        @MainActor
        protocol RootExperience {
            associatedtype Root: View
            func makeRoot(model: RootModel, frameworks: any Presentation.FrameworkBrowserViewModelProtocol) -> Root
        }
    }
#endif
