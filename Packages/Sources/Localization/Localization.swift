import Foundation

/// The engine's localization layer, the bottom of the dependency graph: every target above (the
/// lexer's diagnostics, the parser's, the expander's trace, the validator's findings, the
/// documentation catalog) resolves its user-facing prose here. Language material (keywords, key
/// names, macro spellings, token text) is never translated; it travels inside `arguments`.
///
/// The single artifact is `Engine.xcstrings`, an Xcode String Catalog: authored and translated
/// with Apple's tooling, decoded here directly with Codable so resolution is identical on macOS,
/// iOS, Linux, Windows, and WASM, with zero dependencies. English is the source language and just
/// the first locale; a diagnostic with no template in the catalog renders as its stable code plus
/// arguments, never as silently missing prose.
public enum Localization {
    /// Resolve one catalog key in a locale (source-language fallback per key), substituting
    /// `{0}`, `{1}`, ... with `arguments`. Returns nil when the catalog has no such key.
    public static func render(key: String, arguments: [String] = [], locale: String = "en") -> String? {
        guard let template = Strings.string(forKey: key, locale: locale) else { return nil }
        var result = template
        for (index, argument) in arguments.enumerated() {
            result = result.replacingOccurrences(of: "{\(index)}", with: argument)
        }
        return result
    }

    /// The honest fallback rendering when no template exists: stable code plus arguments.
    public static func fallback(code: String, arguments: [String]) -> String {
        arguments.isEmpty ? code : "\(code) (\(arguments.joined(separator: ", ")))"
    }
}
