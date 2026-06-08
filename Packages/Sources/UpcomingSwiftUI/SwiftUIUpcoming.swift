#if canImport(SwiftUI)
    import SwiftUI

    /// Forward-compat shim for the Liquid Glass SwiftUI APIs, the Pattern 13 wrapper from
    /// docs/rules/cross-platform.md. Call sites read `view.upcoming.glassButtonStyle()` and
    /// `view.upcoming.backgroundExtensionEffect()` with no inline `if #available` ceremony;
    /// the single back-deployment switchover lives here.
    ///
    /// This app already builds against the macOS 26 / iOS 26 SDK (the glass APIs exist at
    /// compile time) but deploys to macOS 15 / iOS 17, so each method is the rule's "Aging"
    /// form: it calls the real API under `if #available` and falls back below it. When the
    /// deployment target reaches 26, delete this wrapper and inline the real API at the two
    /// call sites (the rule's "Aging" step 3). See cupertino-desktop #52.
    public struct SwiftUIUpcoming<Content> {
        public let content: Content
        public init(_ content: Content) {
            self.content = content
        }
    }

    public extension View {
        /// Namespace accessor for the forward-compat Liquid Glass methods.
        var upcoming: SwiftUIUpcoming<Self> {
            SwiftUIUpcoming(self)
        }
    }

    @MainActor
    public extension SwiftUIUpcoming where Content: View {
        /// The Liquid Glass button style (`GlassButtonStyle`, macOS 26 / iOS 26+), so a button
        /// reads as a glass capsule that tracks the surrounding chrome. Falls back to the
        /// borderless style below 26, where `GlassButtonStyle` does not exist.
        @ViewBuilder
        func glassButtonStyle() -> some View {
            if #available(macOS 26, iOS 26, *) {
                content.buttonStyle(.glass)
            } else {
                content.buttonStyle(.borderless)
            }
        }

        /// Extends the view's content beneath adjacent Liquid Glass bars
        /// (`backgroundExtensionEffect()`, macOS 26 / iOS 26+) by mirroring and blurring its
        /// edges into the bars' safe areas, so the glass refracts the content instead of empty
        /// chrome (the HIG "extend content beneath the sidebar" technique). A no-op below 26.
        @ViewBuilder
        func backgroundExtensionEffect() -> some View {
            if #available(macOS 26, iOS 26, *) {
                content.backgroundExtensionEffect()
            } else {
                content
            }
        }
    }
#endif
