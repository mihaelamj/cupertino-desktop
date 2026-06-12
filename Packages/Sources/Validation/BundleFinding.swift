import Foundation
import Localization

/// One semantic finding about a bundle, as TYPED DATA: `code` names the finding stably
/// (`node_unresolved_definition`, `option_default_not_in_values`, ...), `arguments` carry the
/// specifics (paths, identifiers, values; language material, never translated). Prose renderings
/// come from the String Catalog (`validation.<code>` templates); `text` is the English one,
/// byte-identical to the historical issue strings.
public struct BundleFinding: Equatable, Sendable {
    public let code: String
    public let arguments: [String]

    public init(code: String, arguments: [String]) {
        self.code = code
        self.arguments = arguments
    }

    /// The English rendering (the CLI's output).
    public var text: String {
        localizedText(locale: "en")
    }

    /// The rendering in any catalog locale.
    public func localizedText(locale: String) -> String {
        Localization.render(key: "validation." + code, arguments: arguments, locale: locale)
            ?? Localization.fallback(code: code, arguments: arguments)
    }
}
