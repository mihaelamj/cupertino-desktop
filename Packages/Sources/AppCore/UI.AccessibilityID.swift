public extension UI {
    /// Stable accessibility identifiers, the single source of truth shared by the views
    /// (which apply them with `.accessibilityIdentifier(...)` / `accessibilityIdentifier =`)
    /// and the UI-test page objects (which locate elements by them). Keeping them here,
    /// not duplicated as string literals in each shell and each test, prevents drift, and
    /// because page objects match on the identifier they drive SwiftUI, AppKit, and UIKit
    /// identically.
    enum AccessibilityID {
        /// The framework browser (sidebar list + reader detail).
        public enum FrameworkBrowser {
            public static let sidebar = "framework_browser_sidebar"
            public static let reader = "framework_browser_reader"

            /// Identifier for a framework row, qualified by the framework id.
            public static func row(_ frameworkID: String) -> String {
                "framework_row_\(frameworkID)"
            }
        }

        /// The document reader (shared across the framework browser and search).
        public enum Reader {
            public static let textLarger = "reader_text_larger"
            public static let textSmaller = "reader_text_smaller"
        }

        /// The search screen.
        public enum Search {
            public static let field = "search_field"
            public static let scope = "search_scope"
            public static let results = "search_results"
        }

        /// The top-level tabs.
        public enum Tab {
            public static let frameworks = "tab_frameworks"
            public static let search = "tab_search"
        }
    }
}
