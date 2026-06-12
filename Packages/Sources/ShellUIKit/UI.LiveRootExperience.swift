import AppCore
import PresentationBridge

#if canImport(UIKit)
    import UIKit

    public extension UI {
        /// The live UIKit shell: builds `RootViewController` (a `UISplitViewController`)
        /// over the shared `RootModel` and the feature view models.
        struct LiveRootExperience: RootExperience {
            public init() {}

            public func makeRoot(model: RootModel, frameworks: any Presentation.FrameworkBrowserViewModelProtocol) -> UIViewController {
                RootViewController(model: model, frameworks: frameworks)
            }
        }
    }
#endif
