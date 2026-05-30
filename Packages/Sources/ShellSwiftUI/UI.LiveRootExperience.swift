import AppCore
import FrameworkBrowserFeature

#if canImport(SwiftUI)
    import SwiftUI

    public extension UI {
        /// The live SwiftUI shell: builds `RootView` over the shared `RootModel` and
        /// the feature view models.
        struct LiveRootExperience: RootExperience {
            public init() {}

            public func makeRoot(model: RootModel, frameworks: Feature.FrameworkBrowser.ViewModel) -> some View {
                RootView(model: model, frameworks: frameworks)
            }
        }
    }
#endif
