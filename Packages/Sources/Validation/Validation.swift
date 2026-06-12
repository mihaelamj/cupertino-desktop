import Foundation

public struct Validation<Subject, Document> {
    public typealias Context = ValidationContext<Subject, Document>

    public let description: String?
    public let validate: (Context) -> [ValidationError]
    public let predicate: (Context) -> Bool

    public init(
        description: String? = nil,
        check: @escaping (Context) -> [ValidationError],
        when: @escaping (Context) -> Bool = { _ in true },
    ) {
        self.description = description
        validate = check
        predicate = when
    }

    public init(
        description: String,
        code: String? = nil,
        check: @escaping (Context) -> Bool,
        when: @escaping (Context) -> Bool = { _ in true },
    ) {
        self.description = description
        validate = { context in
            if check(context) {
                []
            } else if let code {
                // Typed rule violation: prose resolves from the catalog per locale.
                [ValidationError(ruleCode: code, at: context.codingPath)]
            } else {
                [ValidationError(reason: "Failed to satisfy: \(description)", at: context.codingPath)]
            }
        }
        predicate = when
    }

    public func apply(to subject: Subject, at codingPath: [CodingKey], in document: Document) -> [ValidationError] {
        let context = Context(document: document, subject: subject, codingPath: codingPath)
        guard predicate(context) else { return [] }
        return validate(context)
    }
}
