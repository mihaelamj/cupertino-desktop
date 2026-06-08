import Foundation
@testable import MacBackendImpl
import Testing

/// Tests for resolving the `cupertino` binary, the install check the macOS app runs before
/// launching the subprocess. The point of the resolver is that it finds cupertino even under
/// the minimal `PATH` a GUI / launchd / XCUITest launch inherits, so these tests drive it
/// with controlled environments rather than the process's real `PATH`.
@Suite("Cupertino executable resolution")
struct CupertinoExecutableTests {
    @Test("An absolute path to an executable resolves to itself")
    func absoluteExecutableResolves() {
        #expect(CupertinoExecutable.resolve(name: "/bin/ls") == "/bin/ls")
    }

    @Test("An absolute path to a non-executable resolves to nil")
    func absoluteNonExecutableIsNil() {
        #expect(CupertinoExecutable.resolve(name: "/nope/not-a-real-binary") == nil)
    }

    @Test("A bare name is found in a PATH directory (the standard dirs take precedence)")
    func bareNameFoundOnPATH() throws {
        // A name that is not present in any standard directory, so the PATH branch is the
        // one that resolves it (standard dirs are searched first by design, preferring a
        // Homebrew install over whatever happens to be on PATH).
        let name = "cupertino-resolve-probe-\(UInt64.random(in: 0 ..< .max))"
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cupertino-resolve-\(UInt64.random(in: 0 ..< .max))", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let binary = directory.appendingPathComponent(name)
        try Data().write(to: binary)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)

        let resolved = CupertinoExecutable.resolve(name: name, environment: ["PATH": directory.path])
        #expect(resolved == binary.path)
    }

    @Test("A bare name absent from every searched directory resolves to nil")
    func missingBinaryIsNil() {
        // Minimal PATH (what a GUI launch sees) and a name that is not in any standard dir.
        let resolved = CupertinoExecutable.resolve(name: "definitely-not-installed-xyz", environment: ["PATH": "/usr/bin:/bin"])
        #expect(resolved == nil)
    }

    @Test("On a machine with cupertino installed, it resolves even under a minimal PATH")
    func installedCupertinoResolvesWithoutPATH() {
        // No-op on machines without a Homebrew cupertino (CI runners, fresh clones); on a
        // dev machine it proves the resolver finds the binary the GUI launch's PATH would miss.
        guard FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/cupertino") else { return }
        let resolved = CupertinoExecutable.resolve(environment: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"])
        #expect(resolved == "/opt/homebrew/bin/cupertino")
        #expect(CupertinoExecutable.isInstalled)
    }
}
