@testable import AppModels
import Foundation
import Testing

/// Tests for the app settings file: the default (the Mac's stdio MCP backend), and a
/// round-trip through the JSON file. The file URL is injected so the tests never touch the
/// real Application Support location.
@Suite("App settings")
struct AppSettingsTests {
    @Test("The default backend mode is the stdio MCP subprocess")
    func defaultsToMCPSubprocess() {
        #expect(Model.AppSettings().backend == .mcpSubprocess)
    }

    @Test("A missing settings file loads the defaults")
    func missingFileLoadsDefaults() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cupertino-settings-\(UInt64.random(in: 0 ..< .max))/settings.json")
        #expect(Model.AppSettings.load(from: url) == Model.AppSettings())
    }

    @Test("Settings round-trip through the JSON file")
    func roundTrips() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cupertino-settings-\(UInt64.random(in: 0 ..< .max))/settings.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let settings = Model.AppSettings(backend: .embedded)
        try Model.AppSettings.save(settings, to: url)
        #expect(Model.AppSettings.load(from: url) == settings)
    }
}
