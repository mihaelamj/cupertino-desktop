import Foundation
import Localization

/// A syntax error with a precise source position, thrown by the lexer and parser and reported by
/// the `check` command (and any IDE integration). The position is 1-based line and column.
///
/// Diagnostics are TYPED DATA, not prose: every throw site constructs a `Kind` case whose
/// associated values carry the specifics (the predictive parser knows exactly what it expected at
/// every decision point, so the diagnostic carries that knowledge instead of a hand-written
/// sentence). Prose lives in the String Catalog (`Engine.xcstrings`) as `diagnostic.<code>`
/// templates with `{0}` placeholders; English is just the first language. Language material
/// (keywords, token spellings, key names) travels in the arguments and is never translated.
public struct SyntaxError: Error, CustomStringConvertible {
    public enum Kind: Equatable, Sendable {
        case unexpectedCharacter(String)
        case unterminatedString
        case unexpectedEndOfFile
        case unexpectedEndOfFileInUnitBody
        case unexpectedEndOfFileInValue
        case expectedToken(expected: String, foundType: String, foundValue: String)
        case rootMustBeTemplate(found: String)
        case trailingInput(found: String)
        case expectedKeyAfterLet
        case expectedKeyAfterLetInOption
        case expectedKeyAfterLetInNode
        case expectedKeyAfterLetInUnit
        case expectedKeyAfterLetInUnitNode
        case expectedTemplateItem(found: String)
        case expectedOptionItem(foundType: String, foundValue: String)
        case expectedUnitItem(foundType: String, foundValue: String)
        case unexpectedToken(found: String)
        case unexpectedTokenInValue(found: String)
        case unknownBlockType(found: String)
        /// Container nesting inside a value exceeded the parser's bound (editor buffers can
        /// contain anything; the bound turns a stack overflow into a diagnostic).
        case nestingTooDeep(limit: Int)
        /// A foreign error carried through (file IO during parse driving); already prose.
        case wrapped(String)

        /// The stable diagnostic code: the localization key tail and the tooling identity.
        public var code: String {
            switch self {
            case .unexpectedCharacter: "lex.unexpected_character"
            case .unterminatedString: "lex.unterminated_string"
            case .unexpectedEndOfFile: "parse.unexpected_eof"
            case .unexpectedEndOfFileInUnitBody: "parse.unexpected_eof_unit_body"
            case .unexpectedEndOfFileInValue: "parse.unexpected_eof_value"
            case .expectedToken: "parse.expected_token"
            case .rootMustBeTemplate: "parse.root_must_be_template"
            case .trailingInput: "parse.trailing_input"
            case .expectedKeyAfterLet: "parse.expected_key_after_let"
            case .expectedKeyAfterLetInOption: "parse.expected_key_after_let_option"
            case .expectedKeyAfterLetInNode: "parse.expected_key_after_let_node"
            case .expectedKeyAfterLetInUnit: "parse.expected_key_after_let_unit"
            case .expectedKeyAfterLetInUnitNode: "parse.expected_key_after_let_unit_node"
            case .expectedTemplateItem: "parse.expected_template_item"
            case .expectedOptionItem: "parse.expected_option_item"
            case .expectedUnitItem: "parse.expected_unit_item"
            case .unexpectedToken: "parse.unexpected_token"
            case .unexpectedTokenInValue: "parse.unexpected_token_value"
            case .unknownBlockType: "parse.unknown_block"
            case .nestingTooDeep: "parse.nesting_too_deep"
            case .wrapped: "parse.wrapped"
            }
        }

        /// The specifics, in `{0}`-placeholder order. Language material, untranslated.
        public var arguments: [String] {
            switch self {
            case let .unexpectedCharacter(c): [c]
            case .unterminatedString, .unexpectedEndOfFile,
                 .unexpectedEndOfFileInUnitBody, .unexpectedEndOfFileInValue,
                 .expectedKeyAfterLet, .expectedKeyAfterLetInOption, .expectedKeyAfterLetInNode,
                 .expectedKeyAfterLetInUnit, .expectedKeyAfterLetInUnitNode:
                []
            case let .expectedToken(expected, foundType, foundValue): [expected, foundType, foundValue]
            case let .rootMustBeTemplate(found): [found]
            case let .trailingInput(found): [found]
            case let .expectedTemplateItem(found): [found]
            case let .expectedOptionItem(foundType, foundValue): [foundType, foundValue]
            case let .expectedUnitItem(foundType, foundValue): [foundType, foundValue]
            case let .unexpectedToken(found): [found]
            case let .unexpectedTokenInValue(found): [found]
            case let .unknownBlockType(found): [found]
            case let .nestingTooDeep(limit): [String(limit)]
            case let .wrapped(text): [text]
            }
        }
    }

    public let line: Int
    public let column: Int
    public let kind: Kind

    public init(line: Int, column: Int, kind: Kind) {
        self.line = line
        self.column = column
        self.kind = kind
    }

    /// The stable diagnostic code.
    public var code: String {
        kind.code
    }

    /// The template arguments.
    public var arguments: [String] {
        kind.arguments
    }

    /// The English rendering (the CLI's output and the historical text), resolved from the
    /// catalog like every other language; the code-plus-arguments fallback only fires when the
    /// catalog resource itself is missing.
    public var message: String {
        localizedMessage(locale: "en")
    }

    /// The rendering in any catalog locale.
    public func localizedMessage(locale: String) -> String {
        Localization.render(key: "diagnostic." + kind.code, arguments: kind.arguments, locale: locale)
            ?? Localization.fallback(code: kind.code, arguments: kind.arguments)
    }

    public var description: String {
        "line \(line), column \(column): \(message)"
    }
}
