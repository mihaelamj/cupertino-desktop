import BackendAPI
import CatalogStoreAPI

public extension MobileBackend {
    /// Build a synchronously injectable backend that opens a catalog-backed embedded
    /// engine on first use.
    ///
    /// Mobile app entry points can create feature view models synchronously while
    /// catalog resolution and CupertinoDataEngine construction remain async inside the
    /// backend boundary.
    static func deferred(catalogStore: any Catalog.Store) -> any Backend.Documentation {
        DeferredCatalogBackend(catalogStore: catalogStore)
    }
}
