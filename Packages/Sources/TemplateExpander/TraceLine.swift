import Foundation
import Localization

/// One step of an expansion, as TYPED DATA: `code` names the event stably, `arguments` carry the
/// specifics (paths, identifiers, values; language material, never translated). Prose renderings
/// come from the String Catalog (`trace.<code>` templates); `text` is the English one, identical
/// to the historical trace lines. The IDE classifies and localizes by code; nothing parses prose.
public struct TraceLine: Equatable, Sendable {
    public let code: String
    public let arguments: [String]

    public init(code: String, arguments: [String]) {
        self.code = code
        self.arguments = arguments
    }

    /// The English rendering (the CLI's `--trace` output).
    public var text: String {
        localizedText(locale: "en")
    }

    /// The rendering in any catalog locale.
    public func localizedText(locale: String) -> String {
        Localization.render(key: "trace." + code, arguments: arguments, locale: locale)
            ?? Localization.fallback(code: code, arguments: arguments)
    }
}
