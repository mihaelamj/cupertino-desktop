import Foundation
import SharedModels
@testable import TemplateExpander
import Testing

@Suite("TemplateExpander Tests")
struct TemplateExpanderTests {
    @Test("Verifies simple init or placeholder")
    func placeholder() {
        #expect(true)
    }
}

@Suite("Expansion confinement")
struct ExpansionConfinementTests {
    @Test("a relative escape in a choice value is refused, not written")
    func relativeEscapeRefused() throws {
        let manager = FileManager.default
        let scratch = manager.temporaryDirectory.appendingPathComponent("confine-\(UUID().uuidString)")
        defer { try? manager.removeItem(at: scratch) }
        let out = scratch.appendingPathComponent("out")
        try manager.createDirectory(at: out, withIntermediateDirectories: true)
        let bundle = XcodeTemplateBundle(
            name: "Confine",
            identifier: "com.example.confine",
            metadata: [
                "Kind": .string("Xcode.IDEFoundation.TextSubstitutionFileTemplateKind"),
                "Nodes": .array([.string("___FILEBASENAME___.swift")]),
                "Definitions": .dictionary(["___FILEBASENAME___.swift": .string("struct S {}\n")]),
            ],
            files: [:],
        )
        #expect(throws: ExpanderError.self) {
            try TemplateExpander.expand(bundle, to: out.path, choices: ["fileBasename": "../escaped"])
        }
        #expect(!manager.fileExists(atPath: scratch.appendingPathComponent("escaped.swift").path))
    }

    @Test("a normal expansion stays confined and succeeds")
    func normalExpansionUnaffected() throws {
        let manager = FileManager.default
        let scratch = manager.temporaryDirectory.appendingPathComponent("confine-ok-\(UUID().uuidString)")
        defer { try? manager.removeItem(at: scratch) }
        let out = scratch.appendingPathComponent("out")
        try manager.createDirectory(at: out, withIntermediateDirectories: true)
        let bundle = XcodeTemplateBundle(
            name: "Confine",
            identifier: "com.example.confine",
            metadata: [
                "Kind": .string("Xcode.IDEFoundation.TextSubstitutionFileTemplateKind"),
                "Nodes": .array([.string("___FILEBASENAME___.swift")]),
                "Definitions": .dictionary(["___FILEBASENAME___.swift": .string("struct S {}\n")]),
            ],
            files: [:],
        )
        try TemplateExpander.expand(bundle, to: out.path, choices: ["fileBasename": "Fine"])
        #expect(manager.fileExists(atPath: out.appendingPathComponent("Fine.swift").path))
    }
}
