import CupertinoDataKit
import Foundation

extension MobileBackend {
    /// A stand-in `Search.DocumentReading` with a small hand-written corpus, used to
    /// run the iOS app before `CupertinoDataEngine` (the real, iOS-buildable read
    /// engine) is published. The data here is mock content, not the real index: it
    /// exists only so the embedded backend and the shared SwiftUI shell can be
    /// exercised on iPhone/iPad today. It is replaced by the real engine through
    /// `MobileBackend.live(dataSource:)` once that package lands.
    struct MockReader: Search.DocumentReading {
        /// Framework slug to document count. Plausible numbers, not measured ones.
        private static let frameworkCounts: [String: Int] = [
            "SwiftUI": 8679,
            "UIKit": 12416,
            "Foundation": 6543,
            "Combine": 412,
            "SwiftData": 286,
            "WidgetKit": 198,
        ]

        /// A couple of readable pages so the reader path is exercisable too.
        private static let documents: [String: String] = [
            "apple-docs://swiftui/view": """
            # View

            A type that represents part of your app's user interface and provides
            modifiers that you use to configure views. (Mock content.)
            """,
            "apple-docs://uikit/uiview": """
            # UIView

            An object that manages the content for a rectangular area on the screen.
            (Mock content.)
            """,
        ]

        // swiftlint:disable:next function_parameter_count
        func search(
            query: String, source _: String?, framework _: String?, language _: String?,
            limit: Int, includeArchive _: Bool,
            minIOS _: String?, minMacOS _: String?, minTvOS _: String?,
            minWatchOS _: String?, minVisionOS _: String?, minSwift _: String?,
        ) async throws -> [Search.Result] {
            Self.documents.keys
                .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
                .sorted()
                .prefix(limit)
                .map { uri in
                    Search.Result(
                        uri: uri,
                        source: "apple-docs",
                        framework: uri.contains("uikit") ? "uikit" : "swiftui",
                        title: uri,
                        summary: "Mock result for \"\(query)\".",
                        filePath: "",
                        wordCount: 12,
                        rank: -1,
                    )
                }
        }

        func getDocumentContent(uri: String, format _: Search.DocumentFormat) async throws -> String? {
            Self.documents[uri]
        }

        func listFrameworks() async throws -> [String: Int] {
            Self.frameworkCounts
        }

        func documentCount() async throws -> Int {
            Self.documents.count
        }

        func disconnect() async {}
    }
}
