import AppModels
import BackendAPI
@testable import LocalEmbeddedBackend
import Testing

extension LocalEmbeddedBackendTests {
    @Test("searchPackages reads through the package searcher")
    func searchPackages() async throws {
        let packageSearcher = FakePackageSearcher(results: [
            packageResult("packages://apple/swift-collections/Sources/Deque.swift", module: "Collections", title: "Deque", rank: -4.0),
        ])
        let backend = Backend.LocalEmbedded(dataSource: FakeDataSource(), packageSearcher: packageSearcher)
        let hits = try await backend.searchPackages(Model.PackageQuery(
            text: "deque",
            appleImport: "SwiftUI",
            floor: Model.PlatformFloor(iOS: "17.0", swift: "6.0"),
            limit: 7,
        ))

        #expect(hits.count == 1)
        #expect(hits.first?.owner == "apple")
        #expect(hits.first?.repo == "swift-collections")
        #expect(hits.first?.path == "Sources/Deque.swift")
        #expect(hits.first?.module == "Collections")
        #expect(hits.first?.score == 4.0)

        let calls = await packageSearcher.calls()
        #expect(calls.query == "deque")
        #expect(calls.limit == 7)
        #expect(calls.availabilityPlatform == "iOS")
        #expect(calls.availabilityMinVersion == "17.0")
        #expect(calls.swiftToolsMinVersion == "6.0")
        #expect(calls.appleImport == "SwiftUI")
    }

    @Test("searchEverything fills the package bucket from the dedicated package searcher")
    func everythingUsesPackageSearcher() async throws {
        let packageSearcher = FakePackageSearcher(results: [
            packageResult("packages://apple/swift-async-algorithms/Sources/AsyncChannel.swift", module: "AsyncAlgorithms", title: "AsyncChannel"),
            packageResult("packages://apple/swift-async-algorithms/Sources/AsyncTimerSequence.swift", module: "AsyncAlgorithms", title: "AsyncTimerSequence"),
        ])
        let backend = Backend.LocalEmbedded(
            dataSource: FakeDataSource(results: [
                docResult("apple-docs://swiftui/task", source: "apple-docs"),
                packageResult("packages://apple/swift-async-algorithms/Sources/AsyncChannel.swift", module: "AsyncAlgorithms", title: "AsyncChannel"),
            ]),
            packageSearcher: packageSearcher,
        )
        let unified = try await backend.searchEverything(Model.UnifiedQuery(
            text: "async",
            framework: "SwiftUI",
            floor: Model.PlatformFloor(macOS: "14.0", swift: "6.0"),
            limitPerSource: 2,
        ))

        #expect(unified.docs.count == 1)
        #expect(unified.packages.map(\.title) == ["AsyncChannel", "AsyncTimerSequence"])

        let calls = await packageSearcher.calls()
        #expect(calls.query == "async")
        #expect(calls.limit == 2)
        #expect(calls.availabilityPlatform == "macOS")
        #expect(calls.availabilityMinVersion == "14.0")
        #expect(calls.swiftToolsMinVersion == "6.0")
        #expect(calls.appleImport == "SwiftUI")
    }
}
