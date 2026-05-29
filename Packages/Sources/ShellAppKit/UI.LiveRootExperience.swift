import DesktopCore

#if canImport(AppKit)
import AppKit

extension UI {
    /// The live AppKit shell: builds `RootViewController` over the shared
    /// `RootModel`.
    public struct LiveRootExperience: RootExperience {
        public init() {}

        public func makeRoot(model: RootModel) -> NSViewController {
            RootViewController(model: model)
        }
    }
}
#endif
