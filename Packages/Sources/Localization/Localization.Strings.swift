import Foundation

public extension Localization {
    /// The String Catalog loader: `Engine.xcstrings` decoded with plain Codable, cached per
    /// locale, source-language fallback per key.
    enum Strings {
        /// Locales present in the catalog.
        public static func availableLocales() -> [String] {
            guard let catalog = catalog() else { return [] }
            var locales: Set<String> = []
            for entry in catalog.strings.values {
                locales.formUnion(entry.localizations.keys)
            }
            return locales.sorted()
        }

        /// The full key table for a locale (cached); the catalog's source language fills gaps.
        public static func table(locale: String) -> [String: String] {
            if let cached = cache.withLock({ $0[locale] }) { return cached }
            var table: [String: String] = [:]
            if let catalog = catalog() {
                let source = catalog.sourceLanguage
                for (key, entry) in catalog.strings {
                    let value = entry.localizations[locale]?.stringUnit.value
                        ?? entry.localizations[source]?.stringUnit.value
                    if let value { table[key] = value }
                }
            }
            cache.withLock { $0[locale] = table }
            return table
        }

        public static func string(forKey key: String, locale: String) -> String? {
            if let value = table(locale: locale)[key] { return value }
            return compiledString(forKey: key, locale: locale)
        }

        /// App builds compile the catalog into per-locale tables instead of shipping the
        /// raw file; serve those when the raw catalog is absent. The explicit locale picks
        /// its lproj directly (the engine's locale parameter, not the process language),
        /// with the source language filling gaps, mirroring the raw path's behavior.
        private static func compiledString(forKey key: String, locale: String) -> String? {
            let sourceLanguage = "en"
            for candidate in locale == sourceLanguage ? [locale] : [locale, sourceLanguage] {
                guard let path = Bundle.module.path(forResource: candidate, ofType: "lproj"),
                      let bundle = Bundle(path: path) else { continue }
                let value = bundle.localizedString(forKey: key, value: missingMarker, table: "Engine")
                if value != missingMarker { return value }
            }
            return nil
        }

        private static let missingMarker = "\u{FFFF}missing"

        // MARK: The String Catalog format (the documented .xcstrings JSON shape)

        struct XCStrings: Codable {
            struct StringUnit: Codable {
                let state: String
                let value: String
            }

            struct LocalizationEntry: Codable {
                let stringUnit: StringUnit
            }

            struct Entry: Codable {
                let extractionState: String?
                let localizations: [String: LocalizationEntry]
            }

            let sourceLanguage: String
            let version: String?
            let strings: [String: Entry]
        }

        private static let cache = Mutex<[String: [String: String]]>([:])
        private static let catalogCache = Mutex<XCStrings??>(nil)

        static func catalog() -> XCStrings? {
            if let cached = catalogCache.withLock({ $0 }) { return cached }
            let loaded: XCStrings? = if let url = Bundle.module.url(forResource: "Engine", withExtension: "xcstrings"),
                                        let data = try? Data(contentsOf: url)
            {
                try? JSONDecoder().decode(XCStrings.self, from: data)
            } else {
                nil
            }
            catalogCache.withLock { $0 = loaded }
            return loaded
        }
    }

    /// A minimal cross-platform lock (Foundation's NSLock everywhere; no platform divergence).
    final class Mutex<Value>: @unchecked Sendable {
        private var value: Value
        private let lock = NSLock()

        public init(_ value: Value) {
            self.value = value
        }

        public func withLock<T>(_ body: (inout Value) -> T) -> T {
            lock.lock()
            defer { lock.unlock() }
            return body(&value)
        }
    }
}
