import AppCore
import PresentationBridge

#if canImport(AppKit)
    import AppKit

    public extension UI {
        /// The AppKit shell-root contract. Parallel to the SwiftUI shell's protocol of
        /// the same qualified name and shape; this one vends an `NSViewController`. The
        /// AppKit app target consumes its conformer through this protocol.
        ///
        /// Same shape as the SwiftUI shell: the app composition root builds the feature
        /// view models and hands them in. One explicit parameter today; a bundle is the
        /// abstraction to extract at the second feature (docs/DESIGN.md).
        @MainActor
        protocol RootExperience {
            func makeRoot(model: RootModel, frameworks: any Presentation.FrameworkBrowserViewModelProtocol) -> NSViewController
        }
    }
#endif
