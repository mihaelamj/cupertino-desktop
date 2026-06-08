import Foundation

public extension Model {
    /// Persisted app settings, written as a JSON file in Application Support and read at the
    /// composition root. A missing or unreadable file yields the defaults, so first launch
    /// (and tests) get the Mac default: the stdio MCP subprocess backend
    /// ([[desktop-cupertino-launch]]).
    struct AppSettings: Codable, Sendable, Equatable {
        public var backend: BackendMode

        public init(backend: BackendMode = .mcpSubprocess) {
            self.backend = backend
        }
    }
}

public extension Model.AppSettings {
    /// The on-disk location: `<Application Support>/<bundle id>/settings.json`.
    static var fileURL: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false,
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let bundleID = Bundle.main.bundleIdentifier ?? "com.mihaelamj.cupertinodesktop"
        return base.appendingPathComponent(bundleID, isDirectory: true).appendingPathComponent("settings.json")
    }

    /// Load settings from `url`, returning the defaults if the file is absent or unreadable.
    static func load(from url: URL = fileURL) -> Model.AppSettings {
        guard let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(Model.AppSettings.self, from: data)
        else {
            return Model.AppSettings()
        }
        return settings
    }

    /// Persist settings to `url`, creating the enclosing directory as needed.
    static func save(_ settings: Model.AppSettings, to url: URL = fileURL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: url, options: .atomic)
    }
}
