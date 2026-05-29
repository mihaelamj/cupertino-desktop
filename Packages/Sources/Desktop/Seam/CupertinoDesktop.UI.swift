import DesktopModels

public extension CupertinoDesktop {
    /// The UI seam. Holds the protocols that both the AppKit and SwiftUI sides
    /// implement, plus the platform typealias and the SwiftUI/AppKit bridge.
    /// Concrete views never live here, only the contracts.
    enum UI {}
}
