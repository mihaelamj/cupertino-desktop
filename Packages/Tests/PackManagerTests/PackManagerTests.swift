@testable import PackManager
import SharedModels
import Testing

@Suite("PackManager Tests")
struct PackManagerTests {
    @Test("Verifies isBinary file check")
    func testIsBinary() {
        #expect(PackManager.isBinary(path: "test.png") == true)
        #expect(PackManager.isBinary(path: "test.txt") == false)
    }
}
