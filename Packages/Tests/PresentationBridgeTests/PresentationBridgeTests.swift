import AppModels
import PresentationBridge
import Testing

@Suite("PresentationBridge")
struct PresentationBridgeTests {
    @Test("load state carries loaded values and failed messages")
    func loadState() {
        let loaded = Presentation.LoadState<[String]>.loaded(["SwiftUI"])
        let failed = Presentation.LoadState<[String]>.failed("missing corpus")

        if case let .loaded(values) = loaded {
            #expect(values == ["SwiftUI"])
        } else {
            Issue.record("expected loaded state")
        }

        if case let .failed(message) = failed {
            #expect(message == "missing corpus")
        } else {
            Issue.record("expected failed state")
        }
    }

    @Test("doc hits group by framework with stable leaf nodes")
    func groupsDocsByFramework() throws {
        let hits = try [
            hit("a", "apple-docs://swiftui/navigation", "swiftui", "Navigation"),
            hit("b", "apple-docs://pdfkit/pdfview", "pdfkit", "PDFView"),
            hit("c", "apple-docs://swiftui/view", "swiftui", "View"),
        ]

        let tree = Presentation.SearchResultTree.make(docs: hits)

        #expect(tree.map(\.title) == ["SwiftUI", "PDFKit"])
        #expect(tree[0].children.map(\.id) == ["a", "c"])
        #expect(tree[0].isLeaf == false)
        #expect(tree[0].children[0].isLeaf)
        #expect(tree[0].children[0].uri?.rawValue == "apple-docs://swiftui/navigation")
        #expect(tree[1].subtitle == "1")
    }

    @Test("missing framework groups under Other")
    func missingFrameworkGroupsUnderOther() throws {
        let tree = try Presentation.SearchResultTree.make(docs: [
            hit("a", "apple-docs://documentation/root", nil, "Root"),
        ])

        #expect(tree.count == 1)
        #expect(tree[0].id == "framework:other")
        #expect(tree[0].title == "Other")
    }

    private func hit(_ id: String, _ uri: String, _ framework: String?, _ title: String) throws -> Model.DocHit {
        try Model.DocHit(
            id: id,
            uri: #require(Model.DocURI(uri)),
            source: .appleDocs,
            title: title,
            framework: framework,
            snippet: "",
            score: 1,
        )
    }
}
