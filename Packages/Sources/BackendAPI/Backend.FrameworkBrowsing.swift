import AppModels

public extension Backend {
    /// Listing the documentation frameworks (the sidebar's source).
    protocol FrameworkBrowsing: Sendable {
        func listFrameworks() async throws -> [Model.Framework]
        func listSources() async throws -> [Model.Source]
        func listSourceHierarchy(source: Model.Source, level: Int, parent: String?) async throws -> [Model.HierarchyItem]
    }
}
