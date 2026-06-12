import Foundation

public extension Presentation {
    /// A pure marker constraining validation subjects.
    protocol Validatable {}

    struct AnyCodingKey: CodingKey {
        public var stringValue: String
        public var intValue: Int?

        public init(stringValue: String) {
            self.stringValue = stringValue
            intValue = nil
        }

        public init(intValue: Int) {
            stringValue = String(intValue)
            self.intValue = intValue
        }
    }

    /// The read-only bundle every check receives: the whole document for cross-cutting
    /// judgments, the subject of the specialized type, and where in the tree it sits.
    struct ValidationContext<Subject, Document> {
        public let document: Document
        public let subject: Subject
        public let codingPath: [CodingKey]

        public init(document: Document, subject: Subject, codingPath: [CodingKey]) {
            self.document = document
            self.subject = subject
            self.codingPath = codingPath
        }
    }

    /// One validation finding: a stable rule code plus the specifics, with the canonical
    /// rendering ("Failed to satisfy: <correct state> at path: ...").
    struct ValidationError: Error, CustomStringConvertible, Equatable {
        public let reason: String
        public let codingPath: [CodingKey]
        /// Stable code of the violated rule; the identity tests and gates assert.
        public let code: String
        /// The specifics, first of which is the legacy finding detail.
        public let arguments: [String]

        public init(reason: String, at codingPath: [CodingKey]) {
            self.reason = reason
            self.codingPath = codingPath
            code = ""
            arguments = []
        }

        public init(ruleCode: String, description: String, arguments: [String] = [], at codingPath: [CodingKey]) {
            code = ruleCode
            self.arguments = arguments
            self.codingPath = codingPath
            reason = "Failed to satisfy: \(description)"
        }

        public var description: String {
            let clean = reason.hasSuffix(".") ? String(reason.dropLast()) : reason
            guard !codingPath.isEmpty else { return "\(clean) at root of document" }
            return "\(clean) at path: \(Self.format(codingPath))"
        }

        /// The coding path rendered alone ("edges[2]", "items[0].children[1]"); empty at the root.
        public var pathString: String {
            Self.format(codingPath)
        }

        static func format(_ path: [CodingKey]) -> String {
            var result = ""
            for key in path {
                if let index = key.intValue {
                    result += "[\(index)]"
                } else {
                    if !result.isEmpty { result += "." }
                    result += key.stringValue
                }
            }
            return result
        }

        public static func == (lhs: ValidationError, rhs: ValidationError) -> Bool {
            lhs.reason == rhs.reason && lhs.code == rhs.code && lhs.arguments == rhs.arguments
                && format(lhs.codingPath) == format(rhs.codingPath)
        }
    }

    /// The one value thrown at the end; tests inspect `.values`.
    struct ValidationErrorCollection: Error, CustomStringConvertible, LocalizedError {
        public let values: [ValidationError]

        public init(_ values: [ValidationError]) {
            self.values = values
        }

        public var description: String {
            values.map(\.description).joined(separator: "\n")
        }

        public var errorDescription: String? {
            description
        }
    }

    /// The atomic value: a positive description of the CORRECT state, a check, and a
    /// gating predicate. The Bool init auto-renders the failure; the multi-error init
    /// returns one error per offender, each with its own path.
    struct Validation<Subject, Document> {
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
            code: String,
            detail: @escaping (Context) -> String,
            check: @escaping (Context) -> Bool,
            when: @escaping (Context) -> Bool = { _ in true },
        ) {
            self.description = description
            validate = { context in
                check(context) ? [] : [
                    ValidationError(
                        ruleCode: code,
                        description: description,
                        arguments: [detail(context)],
                        at: context.codingPath,
                    ),
                ]
            }
            predicate = when
        }

        public func apply(to subject: Subject, at codingPath: [CodingKey], in document: Document) -> [ValidationError] {
            let context = Context(document: document, subject: subject, codingPath: codingPath)
            guard predicate(context) else { return [] }
            return validate(context)
        }
    }

    /// Type erasure so heterogeneous rules live in one list; the runtime filter makes a
    /// `Validation<Subject, _>` fire only on true `Subject` values (an optional never
    /// satisfies its wrapped type).
    struct AnyValidation<Document> {
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

    /// The fluent rule set: a default per document type plus `blank`, rules addable by
    /// value and removable by description identity.
    struct Validator<Document> {
        public private(set) var validations: [AnyValidation<Document>]

        public init(validations: [AnyValidation<Document>] = []) {
            self.validations = validations
        }

        public static var blank: Validator<Document> {
            Validator()
        }

        public func validating(_ validation: Validation<some Any, Document>) -> Self {
            var copy = self
            copy.validations.append(AnyValidation(validation))
            return copy
        }

        /// Removal by identity: the description is the stable key.
        public func withoutValidating(describedAs description: String) -> Self {
            var copy = self
            copy.validations.removeAll { $0.description == description }
            return copy
        }

        public var validationDescriptions: [String] {
            validations.map(\.description)
        }
    }

    /// A document that knows how to OFFER its subjects to a validator: itself at the root plus
    /// every nested value worth judging, each with its coding path. The walk lives with the data
    /// shape, so `blank` and `presentationDefault` traverse identically.
    protocol PresentationValidatable: Validatable {
        static func offer(_ document: Self) -> [(subject: Any, codingPath: [CodingKey])]
    }

    /// The non-throwing recovery accessor's result: the validated document or the errors.
    enum ValidationOutcome<Document> {
        case valid(Document)
        case invalid([ValidationError])
    }
}

public extension Presentation.Validator where Document: Presentation.PresentationValidatable {
    /// Every rule over every offered subject; the inspect form.
    func run(_ document: Document) -> [Presentation.ValidationError] {
        Document.offer(document).flatMap { subject, codingPath in
            validations.flatMap { $0.apply(to: subject, at: codingPath, in: document) }
        }
    }

    /// The throwing gate: untrusted input passes here before work happens.
    func validate(_ document: Document) throws {
        let errors = run(document)
        guard errors.isEmpty else { throw Presentation.ValidationErrorCollection(errors) }
    }

    /// The recovery accessor: valid-or-errors for callers that inspect rather than abort.
    func validationOutcome(of document: Document) -> Presentation.ValidationOutcome<Document> {
        let errors = run(document)
        return errors.isEmpty ? .valid(document) : .invalid(errors)
    }
}
