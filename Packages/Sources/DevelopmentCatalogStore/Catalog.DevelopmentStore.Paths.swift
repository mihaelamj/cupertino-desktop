import CatalogStoreAPI
import Foundation

public extension Catalog.DevelopmentStore {
    /// Environment variable that enables real local catalog composition in mobile app targets.
    static let mobileOptInEnvironmentKey = "CUPERTINO_MOBILE_USE_DEV_CATALOG"

    /// Environment variable used by mobile development composition to point at a local catalog.
    static let catalogPathEnvironmentKey = "CUPERTINO_MOBILE_DEV_CATALOG"

    /// Legacy package-smoke path variable kept so existing local scripts still work.
    static let legacyCatalogPathEnvironmentKey = "CUPERTINO_DESKTOP_EMBEDDED_CORPUS"

    /// Resolve the development catalog location from injected environment values.
    ///
    /// An explicit `CUPERTINO_MOBILE_DEV_CATALOG` wins, the legacy
    /// `CUPERTINO_DESKTOP_EMBEDDED_CORPUS` path remains accepted for package-level
    /// smoke scripts, and otherwise `~/.cupertino` under the injected home directory is
    /// used. Tests pass their own values.
    static func corpusURL(
        environment: [String: String],
        homeDirectory: URL,
    ) -> URL {
        for key in [catalogPathEnvironmentKey, legacyCatalogPathEnvironmentKey] {
            if let path = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
            }
        }
        return homeDirectory.appendingPathComponent(".cupertino", isDirectory: true)
    }
}
