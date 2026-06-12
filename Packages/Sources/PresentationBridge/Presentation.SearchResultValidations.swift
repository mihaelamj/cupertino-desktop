import AppModels
import Foundation

public extension Presentation {
    /// Declarative validations for SearchResultNode.
    enum SearchResultValidations {
        public static let allCodes: [String] = [
            "node.id_empty",
            "node.title_empty",
            "node.leaf_missing_uri",
            "node.group_has_uri",
            "node.duplicate_child_id",
            "node.cyclic_children",
        ]

        public static var idNotEmpty: Validation<SearchResultNode, SearchResultNode> {
            Validation(
                description: "the node identity is not empty",
                code: "node.id_empty",
                detail: { _ in "identity is empty" },
                check: { !$0.subject.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            )
        }

        public static var titleNotEmpty: Validation<SearchResultNode, SearchResultNode> {
            Validation(
                description: "the node title is not empty",
                code: "node.title_empty",
                detail: { $0.subject.id },
                check: { !$0.subject.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            )
        }

        public static var leafHasURI: Validation<SearchResultNode, SearchResultNode> {
            Validation(
                description: "a leaf node carries a document URI",
                code: "node.leaf_missing_uri",
                detail: { $0.subject.id },
                check: { $0.subject.uri != nil },
                when: { $0.subject.children.isEmpty },
            )
        }

        public static var groupHasNoURI: Validation<SearchResultNode, SearchResultNode> {
            Validation(
                description: "a group node does not carry a document URI",
                code: "node.group_has_uri",
                detail: { $0.subject.id },
                check: { $0.subject.uri == nil },
                when: { !$0.subject.children.isEmpty },
            )
        }

        public static var childrenIdentitiesUnique: Validation<SearchResultNode, SearchResultNode> {
            Validation(description: "every child node has a unique identity") { context in
                var seen: Set<String> = []
                var errors: [ValidationError] = []
                for (index, child) in context.subject.children.enumerated() where !seen.insert(child.id).inserted {
                    errors.append(ValidationError(
                        ruleCode: "node.duplicate_child_id",
                        description: "every child node has a unique identity",
                        arguments: [child.id],
                        at: context.codingPath + [AnyCodingKey(stringValue: "children"), AnyCodingKey(intValue: index)],
                    ))
                }
                return errors
            }
        }

        public static var childrenStructureAcyclic: Validation<SearchResultNode, SearchResultNode> {
            Validation(description: "the node children structure is acyclic") { context in
                var visited: Set<String> = [context.subject.id]
                var errors: [ValidationError] = []

                func checkCycle(_ node: SearchResultNode, path: [CodingKey]) {
                    if visited.contains(node.id) {
                        errors.append(ValidationError(
                            ruleCode: "node.cyclic_children",
                            description: "the node children structure is acyclic",
                            arguments: [node.id],
                            at: path,
                        ))
                        return
                    }
                    visited.insert(node.id)
                    for (index, child) in node.children.enumerated() {
                        checkCycle(child, path: path + [AnyCodingKey(stringValue: "children"), AnyCodingKey(intValue: index)])
                    }
                    visited.remove(node.id)
                }

                for (index, child) in context.subject.children.enumerated() {
                    checkCycle(child, path: context.codingPath + [AnyCodingKey(stringValue: "children"), AnyCodingKey(intValue: index)])
                }
                return errors
            }
        }
    }
}

extension Presentation.SearchResultNode: Presentation.PresentationValidatable {
    public static func offer(_ node: Presentation.SearchResultNode) -> [(subject: Any, codingPath: [CodingKey])] {
        var offered: [(subject: Any, codingPath: [CodingKey])] = [(node, [])]
        func walk(_ current: Presentation.SearchResultNode, at path: [CodingKey]) {
            for (index, child) in current.children.enumerated() {
                let childPath = path + [Presentation.AnyCodingKey(stringValue: "children"), Presentation.AnyCodingKey(intValue: index)]
                offered.append((child, childPath))
                walk(child, at: childPath)
            }
        }
        walk(node, at: [])
        return offered
    }
}

public extension Presentation.Validator where Document == Presentation.SearchResultNode {
    static var presentationDefault: Presentation.Validator<Presentation.SearchResultNode> {
        Presentation.Validator.blank
            .validating(Presentation.SearchResultValidations.idNotEmpty)
            .validating(Presentation.SearchResultValidations.titleNotEmpty)
            .validating(Presentation.SearchResultValidations.leafHasURI)
            .validating(Presentation.SearchResultValidations.groupHasNoURI)
            .validating(Presentation.SearchResultValidations.childrenIdentitiesUnique)
            .validating(Presentation.SearchResultValidations.childrenStructureAcyclic)
    }
}
