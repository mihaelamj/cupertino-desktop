import AppCore
import FrameworkBrowserFeature

#if canImport(UIKit)
    import UIKit

    public extension UI {
        /// The live UIKit shell: builds `RootViewController` (a `UISplitViewController`)
        /// over the shared `RootModel` and the feature view models.
        struct LiveRootExperience: RootExperience {
            public init() {}

            public func makeRoot(model: RootModel, frameworks: Feature.FrameworkBrowser.ViewModel) -> UIViewController {
                RootViewController(model: model, frameworks: frameworks)
            }
        }
    }
#endif
