import Foundation

public struct AnyValidation<Document> {
    private let _apply: (Any, [CodingKey], Document) -> [ValidationError]
    private let _description: () -> String

    public init<Subject>(_ validation: Validation<Subject, Document>) {
        _apply = { input, codingPath, document in
            guard let subject = input as? Subject else { return [] }
            guard type(of: subject) == type(of: input) else { return [] }
            return validation.apply(to: subject, at: codingPath, in: document)
        }
        _description = {
            validation.description ?? "Unnamed validation for \(Subject.self)"
        }
    }

    public func apply(to subject: Any, at codingPath: [CodingKey], in document: Document) -> [ValidationError] {
        _apply(subject, codingPath, document)
    }

    public var description: String {
        _description()
    }
}
