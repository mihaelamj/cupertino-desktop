import AppModels

public extension Presentation {
    /// Builds logical trees for search results before concrete shells reify them.
    enum SearchResultTree {
        /// Group flat doc hits into `framework -> hit` nodes for the Docs scope.
        ///
        /// Framework groups keep the ranked order of their first hit. Hits within a
        /// framework keep the search order. Group titles use canonical framework
        /// display names from `AppModels`.
        public static func make(docs hits: [Model.DocHit]) -> [Presentation.SearchResultNode] {
            var order: [String] = []
            var groups: [String: [Model.DocHit]] = [:]

            for hit in hits {
                let key = hit.framework.flatMap { $0.isEmpty ? nil : $0 } ?? "other"
                if groups[key] == nil {
                    order.append(key)
                }
                groups[key, default: []].append(hit)
            }

            return order.map { key in
                let children = (groups[key] ?? []).map { hit in
                    let subtitle = [hit.source.scheme, hit.snippet.isEmpty ? nil : hit.snippet]
                        .compactMap(\.self)
                        .joined(separator: " : ")
                    return Presentation.SearchResultNode(
                        id: hit.id,
                        title: hit.title,
                        subtitle: subtitle.isEmpty ? nil : subtitle,
                        uri: hit.uri,
                    )
                }
                let title = Model.Framework(id: key, name: key, documentCount: 0).displayName
                return Presentation.SearchResultNode(
                    id: "framework:\(key)",
                    title: title,
                    subtitle: "\(children.count)",
                    children: children,
                )
            }
        }
    }
}
