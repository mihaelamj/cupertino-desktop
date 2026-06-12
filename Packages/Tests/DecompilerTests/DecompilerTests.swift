@testable import Decompiler
import SharedModels
import Testing

@Suite("Decompiler Tests")
struct DecompilerTests {
    @Test("Verifies simple formatting value")
    func testFormatValue() {
        let val = PropertyListValue.string("hello")
        let str = Decompiler.formatValue(val)
        #expect(str == "\"hello\"")
    }
}
