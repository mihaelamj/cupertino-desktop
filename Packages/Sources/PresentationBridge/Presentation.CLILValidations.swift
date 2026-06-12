import AppModels
import Foundation

public extension Presentation {
    /// Built-in validation rules for CLIL programs using the Matt Polzin / OpenAPIKit validation standard.
    enum CLILValidations {
        /// P1: Device profile matches physical screen constraints
        public static var deviceSizingIsConsistent: Validation<CLILProgram.Statement, CLILProgram> {
            .init(
                description: "Device profiles have consistent size classes (Mac is regular, iPhone is compact)",
                code: "clil:device:sizing",
                detail: { _ in "Device constraints violated" },
                check: { context in
                    guard case let .device(device, _, sizeClass) = context.subject else { return true }
                    switch device {
                    case .Mac:
                        return sizeClass == .regular
                    case .iPhone:
                        return sizeClass == .compact
                    case .iPad:
                        return true // iPad can be compact or regular depending on orientation / multitask
                    }
                },
            )
        }

        /// P2: Dispatched action arguments have correct type
        public static var dispatchArgumentsAreCorrect: Validation<CLILProgram.Statement, CLILProgram> {
            .init(
                description: "Dispatched actions have arguments matching their expected signature",
                code: "clil:dispatch:signature",
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

        /// P3: Asserted property name exists on target
        public static var assertedPropertiesExist: Validation<CLILProgram.Statement, CLILProgram> {
            .init(
                description: "Asserted property names exist on the target (vm or ui)",
                code: "clil:assert:property",
                detail: { _ in "Property not found" },
                check: { context in
                    guard case let .assert(target, property, _, _) = context.subject else { return true }
                    switch target {
                    case .ui:
                        let valid = ["device", "orientation", "sizeClass", "showsSidebarList", "showsDetailPane", "navigationStackDepth", "activeView"]
                        return valid.contains(property)
                    case .vm:
                        let valid = [
                            "activeSource",
                            "selectedFrameworkID",
                            "isLoading",
                            "isLoadingDocument",
                            "errorMessage",
                            "documentState",
                            "selectedMarkdown",
                            "results",
                            "documents",
                            "state",
                            "text",
                        ]
                        return valid.contains(property)
                    }
                },
            )
        }

        /// Default validator for CLILProgram
        public static var clilDefault: Validator<CLILProgram> {
            Validator(validations: [
                AnyValidation(deviceSizingIsConsistent),
                AnyValidation(dispatchArgumentsAreCorrect),
                AnyValidation(assertedPropertiesExist),
            ])
        }
    }
}
