import AppCore

#if canImport(AppKit)
    import AppKit

    public extension UI {
        /// The AppKit shell-root contract. Parallel to the SwiftUI shell's protocol of
        /// the same qualified name and shape; this one vends an `NSViewController`. The
        /// AppKit app target consumes its conformer through this protocol.
        @MainActor
        protocol RootExperience {
            func makeRoot(model: RootModel) -> NSViewController
        }
    }
#endif
