import Foundation

public extension Model {
    /// The reader's persisted text-size scale, shared across every UI so the +/- control
    /// reads and writes one setting (the SwiftUI `@AppStorage`, the UIKit and AppKit
    /// readers). A multiplier applied on top of the semantic body size; full Dynamic Type
    /// and this control's polish are tracked in the font-scaling issue.
    enum ReaderTextSize {
        public static let key = "cupertino.reader.textScale"
        public static let range: ClosedRange<Double> = 0.7 ... 2.5
        public static let step = 0.1

        /// The current scale, clamped, defaulting to 1.0 when unset.
        public static var current: Double {
            let stored = UserDefaults.standard.double(forKey: key)
            return stored == 0 ? 1 : min(range.upperBound, max(range.lowerBound, stored))
        }

        public static var canIncrease: Bool {
            current < range.upperBound
        }

        public static var canDecrease: Bool {
            current > range.lowerBound
        }

        @discardableResult
        public static func larger() -> Double {
            let value = min(range.upperBound, current + step)
            UserDefaults.standard.set(value, forKey: key)
            return value
        }

        @discardableResult
        public static func smaller() -> Double {
            let value = max(range.lowerBound, current - step)
            UserDefaults.standard.set(value, forKey: key)
            return value
        }
    }
}
