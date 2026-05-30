import CupertinoDataKit
import Foundation

extension MobileBackend {
    /// A stand-in `Search.DocumentReading` with a small hand-written corpus, used to
    /// run the iOS app before `CupertinoDataEngine` (the real, iOS-buildable read
    /// engine) is published. The data here is mock content, not the real index: it
    /// exists only so the embedded backend and the shared shells can be exercised on
    /// iPhone/iPad today. It is replaced by the real engine through
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

        /// A readable overview page per framework, keyed by `apple-docs://<id>/overview`
        /// (the id is the framework name from `listFrameworks`). The detail column reads
        /// this when a framework is selected, so the apps render real markdown content.
        private static let overviews: [String: String] = [
            "SwiftUI": """
            # SwiftUI

            Declarative UI for every Apple platform. You describe the interface as a
            function of state, and the framework keeps the rendering in sync.

            ## Essentials
            - **View**: the protocol every piece of UI conforms to.
            - **State / Binding**: single source of truth and two-way references.
            - **NavigationSplitView**: adaptive multi-column navigation.

            ## Example
            ```swift
            struct ContentView: View {
                @State private var count = 0
                var body: some View {
                    Button("Tapped \\(count)") { count += 1 }
                }
            }
            ```

            _Mock content for the embedded-backend demo._
            """,
            "UIKit": """
            # UIKit

            The imperative, view-controller-based framework for iOS and iPadOS apps.

            ## Essentials
            - **UIView**: manages a rectangular area of content.
            - **UIViewController**: manages a view hierarchy and its lifecycle.
            - **UISplitViewController**: adaptive sidebar/detail container.

            ## Example
            ```swift
            let split = UISplitViewController(style: .tripleColumn)
            split.setViewController(listVC, for: .primary)
            ```

            _Mock content for the embedded-backend demo._
            """,
            "Foundation": """
            # Foundation

            The base layer of types every app builds on: values, collections, dates,
            persistence, and networking primitives.

            ## Essentials
            - **URL / URLSession**: addressing and fetching resources.
            - **Data**: a byte buffer with value semantics.
            - **DateComponents / Calendar**: date math done correctly.

            _Mock content for the embedded-backend demo._
            """,
            "Combine": """
            # Combine

            A declarative framework for processing values over time with publishers and
            subscribers.

            ## Essentials
            - **Publisher**: emits a sequence of values.
            - **Subscriber**: receives them.
            - **Operators**: `map`, `filter`, `debounce`, `combineLatest`, ...

            _Mock content for the embedded-backend demo._
            """,
            "SwiftData": """
            # SwiftData

            Persistence built on Swift macros: declare your model with `@Model` and query
            it with `@Query`, no schema boilerplate.

            ## Essentials
            - **@Model**: turns a class into a persisted entity.
            - **ModelContainer / ModelContext**: storage and the working scratchpad.

            _Mock content for the embedded-backend demo._
            """,
            "WidgetKit": """
            # WidgetKit

            Build widgets for the Home Screen, Lock Screen, and StandBy with SwiftUI and a
            timeline of entries.

            ## Essentials
            - **TimelineProvider**: supplies dated snapshots.
            - **Widget**: the configuration and view.

            _Mock content for the embedded-backend demo._
            """,
        ]

        private static func overviewURI(forFramework id: String) -> String {
            "apple-docs://\(id)/overview"
        }

        // swiftlint:disable:next function_parameter_count
        func search(
            query: String, source _: String?, framework: String?, language _: String?,
            limit: Int, includeArchive _: Bool,
            minIOS _: String?, minMacOS _: String?, minTvOS _: String?,
            minWatchOS _: String?, minVisionOS _: String?, minSwift _: String?,
        ) async throws -> [Search.Result] {
            // The mock matches by framework first (how the detail loads a framework's
            // page); falling back to a title contains-match on the query otherwise.
            let names = Self.frameworkCounts.keys.filter { name in
                if let framework, !framework.isEmpty { return name.caseInsensitiveCompare(framework) == .orderedSame }
                return query.isEmpty || name.localizedCaseInsensitiveContains(query)
            }
            return names.sorted().prefix(limit).map { name in
                Search.Result(
                    uri: Self.overviewURI(forFramework: name),
                    source: "apple-docs",
                    framework: name,
                    title: "\(name) overview",
                    summary: "Overview of \(name).",
                    filePath: "",
                    wordCount: 80,
                    rank: -1,
                )
            }
        }

        func getDocumentContent(uri: String, format _: Search.DocumentFormat) async throws -> String? {
            // Match `apple-docs://<id>/overview` back to the framework's overview page.
            guard let host = uri.split(separator: "/").dropFirst().first.map(String.init) else { return nil }
            return Self.overviews[host] ?? Self.overviews.first { uri.localizedCaseInsensitiveContains($0.key) }?.value
        }

        func listFrameworks() async throws -> [String: Int] {
            Self.frameworkCounts
        }

        func documentCount() async throws -> Int {
            Self.overviews.count
        }

        func disconnect() async {}
    }
}
