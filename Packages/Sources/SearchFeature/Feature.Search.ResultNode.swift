import AppCore
import AppModels

public extension Feature.Search {
    /// A node in the grouped search-results tree. A group node (framework or source) has a
    /// `nil` uri and children; a leaf is a single hit with a `uri` the reader can open.
    /// See cupertino-desktop #51.
    struct ResultNode: Identifiable, Hashable, Sendable {
        public let id: String
        public let title: String
        public let subtitle: String?
        public let uri: Model.DocURI?
        public var children: [ResultNode]

        public init(id: String, title: String, subtitle: String? = nil, uri: Model.DocURI? = nil, children: [ResultNode] = []) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.uri = uri
            self.children = children
        }

        public var isLeaf: Bool {
            children.isEmpty && uri != nil
        }
    }

    /// Group flat doc hits into `framework -> hit` nodes for the Docs scope. Frameworks keep
    /// the ranked order of their first (best) hit; hits within a framework keep search order.
    /// Framework group titles use the canonical display name (SwiftUI, AppKit, ...).
    static func resultTree(docs hits: [Model.DocHit]) -> [ResultNode] {
        var order: [String] = []
        var groups: [String: [Model.DocHit]] = [:]
        for hit in hits {
            let key = hit.framework.flatMap { $0.isEmpty ? nil : $0 } ?? "other"
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(hit)
        }
        return order.map { key in
            let children = (groups[key] ?? []).map { hit in
                let subtitle = [hit.source.scheme, hit.snippet.isEmpty ? nil : hit.snippet]
                    .compactMap(\.self).joined(separator: " : ")
                return ResultNode(id: hit.id, title: hit.title, subtitle: subtitle.isEmpty ? nil : subtitle, uri: hit.uri)
            }
            let title = Model.Framework(id: key, name: key, documentCount: 0).displayName
            return ResultNode(id: "framework:\(key)", title: title, subtitle: "\(children.count)", children: children)
        }
    }
}
