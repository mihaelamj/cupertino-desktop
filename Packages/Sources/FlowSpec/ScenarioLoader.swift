import Foundation

/// Finds and decodes `scenarios/*.json` into `Scenario` values. The default search walks
/// up from the current directory looking for a `scenarios/` directory, so a test launched
/// from any nested target resolves the shared root catalogue; a test can also pass an
/// explicit `searchURL` (e.g. derived from `#filePath`).
public enum ScenarioLoader {
    public enum LoadError: Error, CustomStringConvertible {
        case fileNotFound(path: String)
        case decodingFailed(path: String, underlying: Error)

        public var description: String {
            switch self {
            case let .fileNotFound(path):
                "FlowSpec: scenario not found at `\(path)`"
            case let .decodingFailed(path, underlying):
                "FlowSpec: scenario decode failed for `\(path)`: \(underlying)"
            }
        }
    }

    /// Decode one scenario by `id`, looking up `<searchURL>/<id>.json`.
    public static func load(id: String, searchURL: URL? = nil) throws -> Scenario {
        let base = searchURL ?? defaultSearchURL()
        return try load(contentsOf: base.appendingPathComponent("\(id).json"))
    }

    /// Decode one scenario from an explicit file URL.
    public static func load(contentsOf url: URL) throws -> Scenario {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw LoadError.fileNotFound(path: url.path)
        }
        do {
            return try JSONDecoder().decode(Scenario.self, from: data)
        } catch {
            throw LoadError.decodingFailed(path: url.path, underlying: error)
        }
    }

    /// Walk up from the current directory (up to six levels) to find a `scenarios/`
    /// directory; fall back to `./scenarios` so the loader errors clearly if absent.
    public static func defaultSearchURL() -> URL {
        let fileManager = FileManager.default
        var cursor = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        for _ in 0 ..< 6 {
            let candidate = cursor.appendingPathComponent("scenarios", isDirectory: true)
            if fileManager.fileExists(atPath: candidate.path) { return candidate }
            cursor = cursor.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("scenarios", isDirectory: true)
    }
}
