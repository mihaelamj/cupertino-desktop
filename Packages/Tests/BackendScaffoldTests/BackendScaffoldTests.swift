import BackendAPI
import DesktopModels
import Testing
@testable import MacBackendImpl

@Suite("Backend seam scaffold")
struct BackendScaffoldTests {
    @Test("MacBackend.live() composes an opaque DocumentationBackend")
    func liveComposes() {
        // The composition root returns the seam type, not a concrete: callers
        // cannot tell it is MCP-over-subprocess. This is the contract that lets
        // iOS swap in EmbeddedBackend later with no change above the seam.
        let backend: any Backend.Documentation = MacBackend.live()
        #expect(type(of: backend) is any Backend.Documentation.Type)
    }

    @Test("Unimplemented calls fail honestly rather than returning fake data")
    func unimplementedThrows() async {
        let backend = MacBackend.live()
        await #expect(throws: (any Error).self) {
            _ = try await backend.listFrameworks()
        }
    }

    @Test("Value types carry their fields")
    func modelsHoldData() {
        let framework = Model.Framework(id: "swiftui", name: "SwiftUI", documentCount: 42)
        #expect(framework.id == "swiftui")
        #expect(framework.documentCount == 42)

        let uri = Model.DocURI("apple-docs://swiftui/view")
        #expect(uri.rawValue == "apple-docs://swiftui/view")
    }
}
