import DesktopModels

#if canImport(AppKit) && canImport(SwiftUI)
    import AppKit
    import SwiftUI

    public extension CupertinoDesktop.UI {
        /// Wraps any platform `ViewController` so a SwiftUI tree can embed a screen
        /// produced through the shared screen protocols. This is the one piece of
        /// glue that lets the SwiftUI flow reuse the same `ViewController`-returning
        /// contract the AppKit flow uses.
        struct ControllerView: NSViewControllerRepresentable {
            private let controller: CupertinoDesktop.UI.ViewController

            public init(_ controller: CupertinoDesktop.UI.ViewController) {
                self.controller = controller
            }

            public func makeNSViewController(context _: Context) -> CupertinoDesktop.UI.ViewController {
                controller
            }

            public func updateNSViewController(_: CupertinoDesktop.UI.ViewController, context _: Context) {}
        }
    }
#endif
