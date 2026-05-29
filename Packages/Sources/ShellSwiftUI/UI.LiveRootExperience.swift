import DesktopCore

#if canImport(SwiftUI)
    import SwiftUI

    public extension UI {
        /// The live SwiftUI shell: builds `RootView` over the shared `RootModel`.
        struct LiveRootExperience: RootExperience {
            public init() {}

            public func makeRoot(model: RootModel) -> some View {
                RootView(model: model)
            }
        }
    }
#endif
