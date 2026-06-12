import Foundation
import Localization

public extension Documentation {
    /// The help-text view over the engine's String Catalog (`Engine.xcstrings`, owned by the
    /// `Localization` target): each entry name resolves up to three catalog keys
    /// (`<key>.display`, `<key>.title`, `<key>.body`) into one `Text` value.
    enum Strings {
        /// The texts one entry resolves to in one locale.
        public struct Text: Equatable, Sendable {
            /// Friendly display name (nil = derive from the raw name).
            public let display: String?
            /// One-line summary, the tooltip headline.
            public let title: String
            /// Full help body.
            public let body: String

            public init(display: String?, title: String, body: String) {
                self.display = display
                self.title = title
                self.body = body
            }
        }

        /// Locales present in the catalog.
        public static func availableLocales() -> [String] {
            Localization.Strings.availableLocales()
        }

        /// The help-entry table for a locale (cached): every entry name with at least a title.
        public static func table(locale: String) -> [String: Text] {
            if let cached = cache.withLock({ $0[locale] }) { return cached }
            let raw = Localization.Strings.table(locale: locale)
            var names: Set<String> = []
            for key in raw.keys {
                for suffix in [".display", ".title", ".body"] where key.hasSuffix(suffix) {
                    names.insert(String(key.dropLast(suffix.count)))
                }
            }
            var table: [String: Text] = [:]
            for name in names where !name.hasPrefix("diagnostic.") && !name.hasPrefix("trace.") && !name.hasPrefix("validation.") {
                table[name] = Text(
                    display: raw[name + ".display"],
                    title: raw[name + ".title"] ?? "",
                    body: raw[name + ".body"] ?? "",
                )
            }
            cache.withLock { $0[locale] = table }
            return table
        }

        public static func text(forKey key: String, locale: String) -> Text? {
            table(locale: locale)[key]
        }

        private static let cache = Localization.Mutex<[String: [String: Text]]>([:])
    }
}
