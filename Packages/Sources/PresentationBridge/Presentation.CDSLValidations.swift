import AppModels
import Foundation

public extension Presentation {
    /// Built-in validation rules for CDSL programs using the Matt Polzin / OpenAPIKit validation standard.
    enum CDSLValidations {
        public static let allCodes: [String] = [
            "cdsl.dispatch.signature",
            "cdsl.assert.property",
        ]

        /// CDSL P1: Dispatched action arguments have correct type
        public static var dispatchArgumentsAreCorrect: Validation<CDSLProgram.Statement, CDSLProgram> {
            .init(
                description: "Dispatched actions have arguments matching their expected signature",
                code: "cdsl.dispatch.signature",
                detail: { _ in "Signature mismatch" },
                check: { context in
                    guard case let .dispatch(action, value) = context.subject else { return true }
                    switch action {
                    case .onAppeared, .onRetried:
                        return value == .nilValue
                    case .selectSource:
                        if case .nilValue = value { return true }
                        return (try? value.asString()) != nil
                    case .selectFramework, .selectDocument, .openDocument:
                        if case .nilValue = value { return true }
                        return (try? value.asString()) != nil
                    case .search, .toggleSource, .resizeText:
                        return (try? value.asString()) != nil
                    case .changeLimit:
                        return (try? value.asInt()) != nil
                    }
                },
            )
        }

        /// CDSL P2: Asserted VM property name exists on target view model
        public static var assertedPropertiesExist: Validation<CDSLProgram.Statement, CDSLProgram> {
            .init(
                description: "Asserted VM property names exist on the view model",
                code: "cdsl.assert.property",
                detail: { _ in "Property not found" },
                check: { context in
                    guard case let .assertVM(property, _, _) = context.subject else { return true }
                    return CDSLProgram.VMProperty(rawValue: property) != nil
                },
            )
        }

        /// Default validator for CDSLProgram
        public static var cdslDefault: Validator<CDSLProgram> {
            Validator(validations: [
                AnyValidation(dispatchArgumentsAreCorrect),
                AnyValidation(assertedPropertiesExist),
            ])
        }
    }
}
