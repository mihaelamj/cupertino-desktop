import AppCore

#if canImport(AppKit)
    import AppKit

    public extension UI {
        /// The live AppKit shell: builds `RootViewController` over the shared
        /// `RootModel`.
        struct LiveRootExperience: RootExperience {
            public init() {}

            public func makeRoot(model: RootModel) -> NSViewController {
                RootViewController(model: model)
            }
        }
    }
#endif
