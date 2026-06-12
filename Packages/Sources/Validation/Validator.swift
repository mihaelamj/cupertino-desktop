import Foundation
import SharedModels

public struct Validator<Document> {
    public var validations: [AnyValidation<Document>]

    public init(validations: [AnyValidation<Document>] = []) {
        self.validations = validations
    }

    public static var blank: Validator<Document> {
        Validator(validations: [])
    }

    public func validating(_ validation: Validation<some Any, Document>) -> Self {
        var copy = self
        copy.validations.append(AnyValidation(validation))
        return copy
    }

    /// Removal by identity: the description is the stable key, mirroring `validating`.
    public func withoutValidating(describedAs description: String) -> Self {
        var copy = self
        copy.validations.removeAll { $0.description == description }
        return copy
    }

    public var validationDescriptions: [String] {
        validations.map(\.description)
    }
}

public extension Validator where Document == XcodeTemplateBundle {
    /// Every rule over the whole bundle walk; the inspect form. Dictionary children are
    /// visited in sorted key order so the error list is deterministic, same input same output.
    func run(_ document: XcodeTemplateBundle) -> [ValidationError] {
        var errors: [ValidationError] = []

        func walk(_ value: Any, at path: [CodingKey]) {
            // Apply all validations to this value
            for validation in validations {
                errors.append(contentsOf: validation.apply(to: value, at: path, in: document))
            }

            // Recurse into children
            if let bundle = value as? XcodeTemplateBundle {
                walk(bundle.name, at: path + [AnyCodingKey(stringValue: "name")])
                walk(bundle.identifier, at: path + [AnyCodingKey(stringValue: "identifier")])
                for (key, val) in bundle.metadata.sorted(by: { $0.key < $1.key }) {
                    walk(val, at: path + [AnyCodingKey(stringValue: "metadata"), AnyCodingKey(stringValue: key)])
                }
                for (key, val) in bundle.files.sorted(by: { $0.key < $1.key }) {
                    walk(val, at: path + [AnyCodingKey(stringValue: "files"), AnyCodingKey(stringValue: key)])
                }
            } else if let plistVal = value as? PropertyListValue {
                switch plistVal {
                case let .array(arr):
                    for (index, val) in arr.enumerated() {
                        walk(val, at: path + [AnyCodingKey(intValue: index)])
                    }
                case let .dictionary(dict):
                    for (key, val) in dict.sorted(by: { $0.key < $1.key }) {
                        walk(val, at: path + [AnyCodingKey(stringValue: key)])
                    }
                default:
                    break
                }
            } else if let fileInfo = value as? FileInfo {
                walk(fileInfo.type, at: path + [AnyCodingKey(stringValue: "type")])
                walk(fileInfo.content, at: path + [AnyCodingKey(stringValue: "content")])
            }
        }

        walk(document, at: [])

        return errors
    }

    /// The throwing gate: untrusted input passes here before work happens.
    func validate(_ document: XcodeTemplateBundle) throws {
        let errors = run(document)
        if !errors.isEmpty {
            throw ValidationErrorCollection(errors)
        }
    }

    /// The recovery accessor: valid-or-errors for callers that inspect rather than abort.
    func validationOutcome(of document: XcodeTemplateBundle) -> ValidationOutcome<XcodeTemplateBundle> {
        let errors = run(document)
        return errors.isEmpty ? .valid(document) : .invalid(errors)
    }
}
