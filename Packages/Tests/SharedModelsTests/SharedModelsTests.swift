@testable import SharedModels
import Testing

@Suite("SharedModels Tests")
struct SharedModelsTests {
    @Test("Verifies PropertyListValue string conversion")
    func stringConversion() {
        let val = PropertyListValue.string("hello")
        #expect(val.toFoundation() as? String == "hello")
    }
}
