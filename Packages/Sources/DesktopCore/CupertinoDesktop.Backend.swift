import DesktopModels

public extension CupertinoDesktop {
    /// The backend seam. The `DocumentationBackend` protocol and its error types
    /// land here in milestone M1; the concrete adapter over `cupertino serve`
    /// lives in the `MCPBackend` module and is reached only through this seam.
    enum Backend {}
}
