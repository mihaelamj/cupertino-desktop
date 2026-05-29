public extension CupertinoDesktop {
    /// Namespace for the feature layer. Each feature module adds its own
    /// sub-namespace (Search, FrameworkBrowser, DocReader, SampleBrowser) holding
    /// a `Sendable`, UI-agnostic `@Observable` view model. The anchor lives in
    /// the lowest module so the UI seam can name the model types without
    /// depending on the backend seam.
    enum Feature {}
}
