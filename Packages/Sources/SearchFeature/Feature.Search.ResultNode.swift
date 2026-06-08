import AppCore
import AppModels
import PresentationBridge

public extension Feature.Search {
    /// Compatibility alias for the shared presentation search-result node.
    typealias ResultNode = Presentation.SearchResultNode

    /// Group flat doc hits into `framework -> hit` nodes for the Docs scope. Frameworks keep
    /// the ranked order of their first (best) hit; hits within a framework keep search order.
    /// Framework group titles use the canonical display name (SwiftUI, AppKit, ...).
    static func resultTree(docs hits: [Model.DocHit]) -> [ResultNode] {
        Presentation.SearchResultTree.make(docs: hits)
    }
}
