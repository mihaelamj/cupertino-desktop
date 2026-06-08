@testable import AppModels
import Testing

/// Every backend mode must carry a non-empty SF Symbol and label for the connection-type
/// indicator, and they must be distinct per mode (so the menu-bar icon actually
/// distinguishes the connections).
@Suite("Backend mode presentation")
struct BackendModeTests {
    @Test("Each mode has a non-empty symbol and label")
    func eachModeHasPresentation() {
        for mode in Model.BackendMode.allCases {
            #expect(!mode.systemImage.isEmpty)
            #expect(!mode.label.isEmpty)
        }
    }

    @Test("Symbols and labels are distinct across modes")
    func presentationIsDistinct() {
        let symbols = Set(Model.BackendMode.allCases.map(\.systemImage))
        let labels = Set(Model.BackendMode.allCases.map(\.label))
        #expect(symbols.count == Model.BackendMode.allCases.count)
        #expect(labels.count == Model.BackendMode.allCases.count)
    }
}
