import AppModels
import Foundation

public extension Presentation {
    /// Built-in validation rules for CLL programs using the Matt Polzin / OpenAPIKit validation standard.
    enum CLLValidations {
        public static let allCodes: [String] = [
            "cll.device.sizing",
            "cll.assert.property",
        ]

        /// CLL P1: Device profile matches physical screen constraints
        public static var deviceSizingIsConsistent: Validation<CLLProgram.Statement, CLLProgram> {
            .init(
                description: "Device profiles have consistent size classes (Mac is regular, iPhone is compact)",
                code: "cll.device.sizing",
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

        /// CLL P2: Asserted property name exists on target UI mimic
        public static var assertedPropertiesExist: Validation<CLLProgram.Statement, CLLProgram> {
            .init(
                description: "Asserted UI property names exist on the layout mimic",
                code: "cll.assert.property",
                detail: { _ in "Property not found" },
                check: { context in
                    guard case let .assertUI(property, _, _) = context.subject else { return true }
                    let valid = ["device", "orientation", "sizeClass", "showsSidebarList", "showsDetailPane", "navigationStackDepth", "activeView"]
                    return valid.contains(property)
                },
            )
        }

        /// Default validator for CLLProgram
        public static var cllDefault: Validator<CLLProgram> {
            Validator(validations: [
                AnyValidation(deviceSizingIsConsistent),
                AnyValidation(assertedPropertiesExist),
            ])
        }
    }
}
