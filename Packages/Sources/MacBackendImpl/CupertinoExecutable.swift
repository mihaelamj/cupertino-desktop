import Foundation

/// Resolves the `cupertino` binary to an absolute path so the macOS app can tell whether
/// cupertino is installed before it tries to launch it, and then spawn it without depending
/// on `PATH`.
///
/// A GUI / `launchd` / XCUITest launch inherits only a minimal `PATH`
/// (`/usr/bin:/bin:/usr/sbin:/sbin`), which does not include Homebrew's bindir. Launching
/// the bare name `cupertino` through `/usr/bin/env` therefore fails ("No such file or
/// directory") even when the binary is installed, whereas an absolute path always works.
/// This resolver looks in the standard install locations directly, so it finds cupertino
/// regardless of the launching process's `PATH`.
public enum CupertinoExecutable {
    /// Standard install locations, searched in order: Homebrew on Apple silicon, Homebrew on
    /// Intel, then the system bindir. The launching process's `PATH` entries are searched
    /// after these, so an unusual install location is still found when it is on `PATH`.
    public static let standardDirectories = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]

    /// The absolute path to the `cupertino` binary, or `nil` if it is not installed. An
    /// absolute `name` is returned unchanged when it points at an executable file.
    public static func resolve(
        name: String = "cupertino",
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
    ) -> String? {
        if name.hasPrefix("/") {
            return fileManager.isExecutableFile(atPath: name) ? name : nil
        }
        let pathDirectories = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        for directory in standardDirectories + pathDirectories {
            let candidate = (directory as NSString).appendingPathComponent(name)
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    /// Whether the `cupertino` binary can be found in a standard location or on `PATH`.
    public static var isInstalled: Bool {
        resolve() != nil
    }
}
