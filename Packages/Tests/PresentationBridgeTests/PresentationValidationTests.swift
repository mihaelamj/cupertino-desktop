import AppModels
import PresentationBridge
import Testing

@Suite("Presentation Validation")
struct PresentationValidationTests {
    // MARK: - 1. Failing and Succeeding Pair per Rule

    @Test("Rule idNotEmpty: fails when ID is empty, succeeds when ID is present")
    func ruleIdNotEmpty() {
        let validator = Presentation.Validator<Presentation.SearchResultNode>.blank
            .validating(Presentation.SearchResultValidations.idNotEmpty)

        // Fails
        let invalidNode = Presentation.SearchResultNode(id: " ", title: "Valid Title", uri: Model.DocURI("apple-docs://doc"))
        let errors = validator.run(invalidNode)
        #expect(errors.count == 1)
        #expect(errors.first?.code == "node.id_empty")
        #expect(errors.first?.reason == "Failed to satisfy: the node identity is not empty")

        // Succeeds (Near miss: single non-space character)
        let validNode = Presentation.SearchResultNode(id: "a", title: "Valid Title", uri: Model.DocURI("apple-docs://doc"))
        #expect(validator.run(validNode).isEmpty)
    }

    @Test("Rule titleNotEmpty: fails when title is empty, succeeds when title is present")
    func ruleTitleNotEmpty() {
        let validator = Presentation.Validator<Presentation.SearchResultNode>.blank
            .validating(Presentation.SearchResultValidations.titleNotEmpty)

        // Fails
        let invalidNode = Presentation.SearchResultNode(id: "id1", title: "\n", uri: Model.DocURI("apple-docs://doc"))
        let errors = validator.run(invalidNode)
        #expect(errors.count == 1)
        #expect(errors.first?.code == "node.title_empty")
        #expect(errors.first?.reason == "Failed to satisfy: the node title is not empty")

        // Succeeds (Near miss: single non-space character)
        let validNode = Presentation.SearchResultNode(id: "id1", title: "b", uri: Model.DocURI("apple-docs://doc"))
        #expect(validator.run(validNode).isEmpty)
    }

    @Test("Rule leafHasURI: fails when leaf node is missing URI, succeeds when leaf node has URI")
    func ruleLeafHasURI() {
        let validator = Presentation.Validator<Presentation.SearchResultNode>.blank
            .validating(Presentation.SearchResultValidations.leafHasURI)

        // Fails
        let invalidNode = Presentation.SearchResultNode(id: "id1", title: "Title")
        let errors = validator.run(invalidNode)
        #expect(errors.count == 1)
        #expect(errors.first?.code == "node.leaf_missing_uri")
        #expect(errors.first?.reason == "Failed to satisfy: a leaf node carries a document URI")

        // Succeeds (Near miss: leaf with a valid URI)
        let validNode = Presentation.SearchResultNode(id: "id1", title: "Title", uri: Model.DocURI("apple-docs://doc"))
        #expect(validator.run(validNode).isEmpty)
    }

    @Test("Rule groupHasNoURI: fails when group node has a URI, succeeds when group node has no URI")
    func ruleGroupHasNoURI() {
        let validator = Presentation.Validator<Presentation.SearchResultNode>.blank
            .validating(Presentation.SearchResultValidations.groupHasNoURI)

        let child = Presentation.SearchResultNode(id: "child", title: "Child", uri: Model.DocURI("apple-docs://doc"))

        // Fails
        let invalidNode = Presentation.SearchResultNode(
            id: "group",
            title: "Group",
            uri: Model.DocURI("apple-docs://doc"),
            children: [child],
        )
        let errors = validator.run(invalidNode)
        #expect(errors.count == 1)
        #expect(errors.first?.code == "node.group_has_uri")
        #expect(errors.first?.reason == "Failed to satisfy: a group node does not carry a document URI")

        // Succeeds (Near miss: group with children and no URI)
        let validNode = Presentation.SearchResultNode(
            id: "group",
            title: "Group",
            children: [child],
        )
        #expect(validator.run(validNode).isEmpty)
    }

    @Test("Rule childrenIdentitiesUnique: fails when children have duplicate IDs, succeeds when children IDs are unique")
    func ruleChildrenIdentitiesUnique() {
        let validator = Presentation.Validator<Presentation.SearchResultNode>.blank
            .validating(Presentation.SearchResultValidations.childrenIdentitiesUnique)

        let child1 = Presentation.SearchResultNode(id: "dup", title: "Child 1", uri: Model.DocURI("apple-docs://doc"))
        let child2 = Presentation.SearchResultNode(id: "dup", title: "Child 2", uri: Model.DocURI("apple-docs://doc"))

        // Fails
        let invalidNode = Presentation.SearchResultNode(id: "parent", title: "Parent", children: [child1, child2])
        let errors = validator.run(invalidNode)
        #expect(errors.count == 1)
        #expect(errors.first?.code == "node.duplicate_child_id")
        #expect(errors.first?.reason == "Failed to satisfy: every child node has a unique identity")
        #expect(errors.first?.pathString == "children[1]")

        // Succeeds (Near miss: children with distinct IDs differing by one character)
        let child3 = Presentation.SearchResultNode(id: "dup2", title: "Child 2", uri: Model.DocURI("apple-docs://doc"))
        let validNode = Presentation.SearchResultNode(id: "parent", title: "Parent", children: [child1, child3])
        #expect(validator.run(validNode).isEmpty)
    }

    @Test("Rule childrenStructureAcyclic: fails when children structure has a cycle, succeeds when acyclic")
    func ruleChildrenStructureAcyclic() {
        let validator = Presentation.Validator<Presentation.SearchResultNode>.blank
            .validating(Presentation.SearchResultValidations.childrenStructureAcyclic)

        // We build a cycle parent -> child -> parent
        let child = Presentation.SearchResultNode(id: "parent", title: "Parent as Child", uri: Model.DocURI("apple-docs://doc"))
        let invalidNode = Presentation.SearchResultNode(id: "parent", title: "Parent", children: [child])

        let errors = validator.run(invalidNode)
        #expect(errors.count == 1)
        #expect(errors.first?.code == "node.cyclic_children")
        #expect(errors.first?.pathString == "children[0]")

        // Succeeds (Near miss: parent -> child1 -> child2 with distinct IDs)
        let child2 = Presentation.SearchResultNode(id: "child2", title: "Child 2", uri: Model.DocURI("apple-docs://doc"))
        let child1 = Presentation.SearchResultNode(id: "child1", title: "Child 1", children: [child2])
        let validNode = Presentation.SearchResultNode(id: "parent", title: "Parent", children: [child1])
        #expect(validator.run(validNode).isEmpty)
    }

    // MARK: - 2. Configuration-Pin Test

    @Test("Validator configuration description lists are stable and pinned")
    func validatorConfigurations() {
        let blank = Presentation.Validator<Presentation.SearchResultNode>.blank
        #expect(blank.validationDescriptions.isEmpty)

        let def = Presentation.Validator<Presentation.SearchResultNode>.presentationDefault
        #expect(def.validationDescriptions == [
            "the node identity is not empty",
            "the node title is not empty",
            "a leaf node carries a document URI",
            "a group node does not carry a document URI",
            "every child node has a unique identity",
            "the node children structure is acyclic",
        ])

        let customized = def.withoutValidating(describedAs: "the node identity is not empty")
        #expect(customized.validationDescriptions == [
            "the node title is not empty",
            "a leaf node carries a document URI",
            "a group node does not carry a document URI",
            "every child node has a unique identity",
            "the node children structure is acyclic",
        ])
    }

    // MARK: - 3. Machinery Negative & Positive Control Tests

    @Test("Optional subject yields no errors in type-erased wrapper")
    func optionalSubjectMachinery() throws {
        let validation = Presentation.SearchResultValidations.idNotEmpty
        let erased = Presentation.AnyValidation(validation)

        // An optional of the subject type
        let optionalNode: Presentation.SearchResultNode? = Presentation.SearchResultNode(id: " ", title: "T", uri: Model.DocURI("apple-docs://doc"))
        let errors = try erased.apply(to: optionalNode as Any, at: [], in: #require(optionalNode))
        #expect(errors.isEmpty) // Erased wrapper rejects optionals and returns no errors.
    }

    @Test("Wrong subject type yields no errors in type-erased wrapper")
    func wrongTypeMachinery() {
        let validation = Presentation.SearchResultValidations.idNotEmpty
        let erased = Presentation.AnyValidation(validation)

        let errors = erased.apply(to: "String Subject" as Any, at: [], in: Presentation.SearchResultNode(id: "a", title: "T"))
        #expect(errors.isEmpty) // Erased wrapper returns no errors for mismatched subject type.
    }

    @Test("False predicate (when clause) yields no errors")
    func predicateGatedMachinery() {
        // Build a rule with a false predicate
        let rule = Presentation.Validation<Presentation.SearchResultNode, Presentation.SearchResultNode>(
            description: "always fails check but gated by false predicate",
            code: "test.gated",
            detail: { _ in "" },
            check: { _ in false },
            when: { _ in false },
        )

        let node = Presentation.SearchResultNode(id: "a", title: "T")
        let errors = rule.apply(to: node, at: [], in: node)
        #expect(errors.isEmpty)
    }

    @Test("Positive control: same node twice yields two errors")
    func positiveControlMachinery() {
        let validation = Presentation.SearchResultValidations.idNotEmpty
        let erased = Presentation.AnyValidation(validation)
        let invalidNode = Presentation.SearchResultNode(id: " ", title: "T")

        let errors1 = erased.apply(to: invalidNode, at: [], in: invalidNode)
        let errors2 = erased.apply(to: invalidNode, at: [], in: invalidNode)
        #expect(errors1.count == 1)
        #expect(errors2.count == 1)
        #expect(errors1 == errors2)
    }

    // MARK: - 4. Many-Error Assertions (Complete Error List)

    @Test("Many-error node tree asserts complete error list in order")
    func manyErrorsCompleteList() {
        let validator = Presentation.Validator<Presentation.SearchResultNode>.presentationDefault

        // invalid parent (empty title, group with URI, duplicate child IDs, cyclic children)
        let child1 = Presentation.SearchResultNode(id: "parent", title: "Child 1", uri: Model.DocURI("apple-docs://doc"))
        let child2 = Presentation.SearchResultNode(id: "parent", title: "Child 2", uri: Model.DocURI("apple-docs://doc"))

        let invalidNode = Presentation.SearchResultNode(
            id: "parent",
            title: " ", // Fails titleNotEmpty
            uri: Model.DocURI("apple-docs://doc"), // Fails groupHasNoURI
            children: [child1, child2], // Fails childrenIdentitiesUnique & childrenStructureAcyclic
        )

        let errors = validator.run(invalidNode)

        // Expected errors on the parent node:
        // 1. node.title_empty
        // 2. node.group_has_uri
        // 3. node.duplicate_child_id
        // 4. node.cyclic_children (child1)
        // 5. node.cyclic_children (child2)
        #expect(errors.count == 5)

        #expect(errors[0].code == "node.title_empty")
        #expect(errors[0].pathString == "")

        #expect(errors[1].code == "node.group_has_uri")
        #expect(errors[1].pathString == "")

        #expect(errors[2].code == "node.duplicate_child_id")
        #expect(errors[2].pathString == "children[1]")

        #expect(errors[3].code == "node.cyclic_children")
        #expect(errors[3].pathString == "children[0]")

        #expect(errors[4].code == "node.cyclic_children")
        #expect(errors[4].pathString == "children[1]")
    }

    // MARK: - 5. Coverage Meta-Test

    @Test("Meta-test: every code in the registry has at least one test case generating it")
    func validationCoverageMetaTest() {
        let allCodes = Presentation.SearchResultValidations.allCodes
        var generatedCodes = Set<String>()

        let validator = Presentation.Validator<Presentation.SearchResultNode>.presentationDefault

        // Fixtures covering every code
        let fixtures: [Presentation.SearchResultNode] = [
            // id empty -> "node.id_empty"
            Presentation.SearchResultNode(id: "", title: "Title", uri: Model.DocURI("apple-docs://doc")),
            // title empty -> "node.title_empty"
            Presentation.SearchResultNode(id: "id1", title: "", uri: Model.DocURI("apple-docs://doc")),
            // leaf without uri -> "node.leaf_missing_uri"
            Presentation.SearchResultNode(id: "id1", title: "Title"),
            // group with uri -> "node.group_has_uri"
            Presentation.SearchResultNode(
                id: "group",
                title: "Group",
                uri: Model.DocURI("apple-docs://doc"),
                children: [Presentation.SearchResultNode(id: "child", title: "Child", uri: Model.DocURI("apple-docs://doc"))],
            ),
            // duplicate child id -> "node.duplicate_child_id"
            Presentation.SearchResultNode(
                id: "parent",
                title: "Parent",
                children: [
                    Presentation.SearchResultNode(id: "child", title: "Child 1", uri: Model.DocURI("apple-docs://doc")),
                    Presentation.SearchResultNode(id: "child", title: "Child 2", uri: Model.DocURI("apple-docs://doc")),
                ],
            ),
            // cyclic children -> "node.cyclic_children"
            Presentation.SearchResultNode(
                id: "parent",
                title: "Parent",
                children: [Presentation.SearchResultNode(id: "parent", title: "Parent", uri: Model.DocURI("apple-docs://doc"))],
            ),
        ]

        for fixture in fixtures {
            let errors = validator.run(fixture)
            for error in errors {
                generatedCodes.insert(error.code)
            }
        }

        let missing = Set(allCodes).subtracting(generatedCodes)
        #expect(missing.isEmpty, "Gaps in validation tests coverage: \(missing)")
    }
}
