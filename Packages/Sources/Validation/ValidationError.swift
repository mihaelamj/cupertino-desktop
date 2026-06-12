import Foundation
import Localization

/// One validation finding, as TYPED DATA: `code` names the violated rule stably
/// (`rule.kind_valid`, ...), `arguments` carry the specifics, and prose renderings come from the
/// String Catalog (`validation.<code>` templates plus the `failed_to_satisfy` / position
/// composition). English is just the first language; `reason` and `description` are its
/// renderings, byte-identical to the historical texts.
public struct ValidationError: Error, CustomStringConvertible {
    public let reason: String
    public let codingPath: [CodingKey]
    /// Stable code of the violated rule or finding; empty for free-prose legacy findings.
    public let code: String
    /// The specifics in `{0}`-placeholder order (language material, never translated).
    public let arguments: [String]

    /// Legacy free-prose finding (no stable identity).
    public init(reason: String, at codingPath: [CodingKey]) {
        self.reason = reason
        self.codingPath = codingPath
        code = ""
        arguments = []
    }

    /// A typed rule violation: the reason is the localized composition
    /// "Failed to satisfy: <rule sentence>" rendered in the source language.
    public init(ruleCode: String, arguments: [String] = [], at codingPath: [CodingKey]) {
        code = ruleCode
        self.arguments = arguments
        self.codingPath = codingPath
        let sentence = Localization.render(key: "validation.\(ruleCode)", arguments: arguments, locale: "en")
            ?? Localization.fallback(code: ruleCode, arguments: arguments)
        reason = Localization.render(key: "validation.failed_to_satisfy", arguments: [sentence], locale: "en")
            ?? "Failed to satisfy: \(sentence)"
    }

    public var description: String {
        localizedDescription(locale: "en")
    }

    /// The full rendering in any catalog locale: rule sentence, failure wrapper, position suffix.
    public func localizedDescription(locale: String) -> String {
        let base: String
        if code.isEmpty {
            base = reason
        } else {
            let sentence = Localization.render(key: "validation.\(code)", arguments: arguments, locale: locale)
                ?? Localization.fallback(code: code, arguments: arguments)
            base = Localization.render(key: "validation.failed_to_satisfy", arguments: [sentence], locale: locale)
                ?? "Failed to satisfy: \(sentence)"
        }
        let clean = base.hasSuffix(".") ? String(base.dropLast()) : base
        if codingPath.isEmpty {
            return Localization.render(key: "validation.at_root", arguments: [clean], locale: locale)
                ?? "\(clean) at root of document"
        }
        return Localization.render(key: "validation.at_path", arguments: [clean, formatPath(codingPath)], locale: locale)
            ?? "\(clean) at path: \(formatPath(codingPath))"
    }

    private func formatPath(_ path: [CodingKey]) -> String {
        var result = ""
        for key in path {
            if let index = key.intValue {
                result += "[\(index)]"
            } else {
                if !result.isEmpty {
                    result += "."
                }
                result += key.stringValue
            }
        }
        return result
    }
}
