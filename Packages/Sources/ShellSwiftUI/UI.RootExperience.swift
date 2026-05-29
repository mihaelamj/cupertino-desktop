import DesktopCore

#if canImport(SwiftUI)
    import SwiftUI

    public extension UI {
        /// The SwiftUI shell-root contract. Parallel to the AppKit shell's protocol
        /// of the same qualified name and shape; this one vends a SwiftUI `View`. The
        /// SwiftUI app target consumes its conformer through this protocol.
        @MainActor
        protocol RootExperience {
            associatedtype Root: View
            func makeRoot(model: RootModel) -> Root
        }
    }
#endif
