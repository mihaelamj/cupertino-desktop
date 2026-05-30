import AppCore
import FrameworkBrowserFeature

#if canImport(AppKit)
    import AppKit

    public extension UI {
        /// The live AppKit shell: builds `RootViewController` over the shared
        /// `RootModel` and the feature view models.
        struct LiveRootExperience: RootExperience {
            public init() {}

            public func makeRoot(model: RootModel, frameworks: Feature.FrameworkBrowser.ViewModel) -> NSViewController {
                RootViewController(model: model, frameworks: frameworks)
            }
        }
    }
#endif
