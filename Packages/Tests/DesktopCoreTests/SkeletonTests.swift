import Testing
@testable import DesktopCore

@Suite("M0 skeleton")
struct SkeletonTests {
    @Test("Core namespaces compile and link")
    func namespacesLink() {
        // Smoke test: the UI/Feature namespace anchors resolve. The backend seam
        // lives in BackendAPI now and is covered by BackendScaffoldTests.
        #expect(String(describing: Feature.self).isEmpty == false)
        #expect(String(describing: UI.self).isEmpty == false)
    }

    @Test("Shared root model holds top-level selection")
    @MainActor
    func rootModelSelection() {
        let model = UI.RootModel()
        #expect(model.selectedFrameworkID == nil)
        model.selectedFrameworkID = "swiftui"
        #expect(model.selectedFrameworkID == "swiftui")
    }
}
