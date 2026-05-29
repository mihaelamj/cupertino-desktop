import DesktopModels

#if canImport(AppKit)
    import AppKit

    public extension CupertinoDesktop.UI {
        /// The platform view-controller type every screen returns. Aliasing keeps
        /// the protocol return type identical across frameworks (an `NSViewController`
        /// on macOS); a `UIViewController` alias is added when iOS lands.
        typealias ViewController = NSViewController
    }
#endif
