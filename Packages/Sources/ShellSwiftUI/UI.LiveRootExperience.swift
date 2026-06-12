import AppCore
import PresentationBridge

#if canImport(SwiftUI)
    import SwiftUI

    public extension UI {
        /// The live SwiftUI shell: builds `RootView` over the shared `RootModel` and
        /// the feature view models.
        struct LiveRootExperience: RootExperience {
            public init() {}

            public func makeRoot(model: RootModel, frameworks: any Presentation.FrameworkBrowserViewModelProtocol) -> some View {
                AnyView(openRootView(model: model, frameworks: frameworks))
            }

            private func openRootView(model: RootModel, frameworks: some Presentation.FrameworkBrowserViewModelProtocol) -> some View {
                RootView(model: model, frameworks: frameworks)
            }
        }
    }
#endif
