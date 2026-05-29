@testable import DesktopCore
import DesktopModels
import Testing

@Suite("M0 skeleton")
struct BackendTests {
    @Test("Layered namespaces compile and link")
    func namespacesLink() {
        // M0 smoke test: the Foundation -> Infrastructure -> Features namespace
        // tree resolves across module boundaries. Real behavior arrives in M1.
        #expect(String(describing: CupertinoDesktop.Backend.self).isEmpty == false)
        #expect(String(describing: CupertinoDesktop.Feature.self).isEmpty == false)
    }
}
