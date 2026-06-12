import AppModels
import PresentationBridge
import Testing

@Suite("CDSL and CLL Validation Suite")
struct PresentationCDSL_CLLValidationTests {
    // MARK: - 1. Failing and Succeeding Pair per Rule (CDSL)

    @Test("CDSL Rule dispatchArgumentsAreCorrect: fails on wrong argument type, succeeds on correct type")
    func ruleCDSLDispatchArguments() {
        let validator = Presentation.Validator<Presentation.CDSLProgram>.blank
            .validating(Presentation.CDSLValidations.dispatchArgumentsAreCorrect)

        // Fails: selectSource with integer
        let invalidStmt1 = Presentation.CDSLProgram.Statement.dispatch(.selectSource, .number(42))
        let program1 = Presentation.CDSLProgram(statements: [invalidStmt1])
        let errors1 = validator.run(program1)
        #expect(errors1.count == 1)
        #expect(errors1.first?.code == "cdsl.dispatch.signature")
        #expect(errors1.first?.reason == "Failed to satisfy: Dispatched actions have arguments matching their expected signature")

        // Fails: onAppeared with string
        let invalidStmt2 = Presentation.CDSLProgram.Statement.dispatch(.onAppeared, .string("hello"))
        let program2 = Presentation.CDSLProgram(statements: [invalidStmt2])
        let errors2 = validator.run(program2)
        #expect(errors2.count == 1)

        // Succeeds (Near miss: selectSource with string)
        let validStmt1 = Presentation.CDSLProgram.Statement.dispatch(.selectSource, .string("apple-docs"))
        let program3 = Presentation.CDSLProgram(statements: [validStmt1])
        #expect(validator.run(program3).isEmpty)

        // Succeeds (Near miss: onAppeared with nil)
        let validStmt2 = Presentation.CDSLProgram.Statement.dispatch(.onAppeared, .nilValue)
        let program4 = Presentation.CDSLProgram(statements: [validStmt2])
        #expect(validator.run(program4).isEmpty)
    }

    @Test("CDSL Rule assertedPropertiesExist: fails on unknown property, succeeds on known property")
    func ruleCDSLAssertedProperties() {
        let validator = Presentation.Validator<Presentation.CDSLProgram>.blank
            .validating(Presentation.CDSLValidations.assertedPropertiesExist)

        // Fails
        let invalidStmt = Presentation.CDSLProgram.Statement.assertVM("wrongVMProperty", .eq, .string("idle"))
        let program1 = Presentation.CDSLProgram(statements: [invalidStmt])
        let errors = validator.run(program1)
        #expect(errors.count == 1)
        #expect(errors.first?.code == "cdsl.assert.property")

        // Succeeds (Near miss: activeSource)
        let validStmt = Presentation.CDSLProgram.Statement.assertVM("activeSource", .eq, .string("appleDocs"))
        let program2 = Presentation.CDSLProgram(statements: [validStmt])
        #expect(validator.run(program2).isEmpty)
    }

    // MARK: - 2. Failing and Succeeding Pair per Rule (CLL)

    @Test("CLL Rule deviceSizingIsConsistent: fails on mismatched sizing, succeeds on aligned sizing")
    func ruleCLLDeviceSizing() {
        let validator = Presentation.Validator<Presentation.CLLProgram>.blank
            .validating(Presentation.CLLValidations.deviceSizingIsConsistent)

        // Fails: iPhone with regular size class
        let invalidStmt1 = Presentation.CLLProgram.Statement.device(.iPhone, .portrait, .regular)
        let program1 = Presentation.CLLProgram(statements: [invalidStmt1])
        let errors1 = validator.run(program1)
        #expect(errors1.count == 1)
        #expect(errors1.first?.code == "cll.device.sizing")

        // Fails: Mac with compact size class
        let invalidStmt2 = Presentation.CLLProgram.Statement.device(.Mac, .landscape, .compact)
        let program2 = Presentation.CLLProgram(statements: [invalidStmt2])
        let errors2 = validator.run(program2)
        #expect(errors2.count == 1)

        // Succeeds (Near miss: iPhone portrait compact)
        let validStmt1 = Presentation.CLLProgram.Statement.device(.iPhone, .portrait, .compact)
        let program3 = Presentation.CLLProgram(statements: [validStmt1])
        #expect(validator.run(program3).isEmpty)

        // Succeeds (Near miss: Mac landscape regular)
        let validStmt2 = Presentation.CLLProgram.Statement.device(.Mac, .landscape, .regular)
        let program4 = Presentation.CLLProgram(statements: [validStmt2])
        #expect(validator.run(program4).isEmpty)
    }

    @Test("CLL Rule assertedPropertiesExist: fails on unknown UI property, succeeds on known UI property")
    func ruleCLLAssertedProperties() {
        let validator = Presentation.Validator<Presentation.CLLProgram>.blank
            .validating(Presentation.CLLValidations.assertedPropertiesExist)

        // Fails
        let invalidStmt = Presentation.CLLProgram.Statement.assertUI("wrongUIProperty", .eq, .string("Mac"))
        let program1 = Presentation.CLLProgram(statements: [invalidStmt])
        let errors = validator.run(program1)
        #expect(errors.count == 1)
        #expect(errors.first?.code == "cll.assert.property")

        // Succeeds (Near miss: device)
        let validStmt = Presentation.CLLProgram.Statement.assertUI("device", .eq, .string("Mac"))
        let program2 = Presentation.CLLProgram(statements: [validStmt])
        #expect(validator.run(program2).isEmpty)
    }

    // MARK: - 3. Configuration-Pin Test

    @Test("CDSL and CLL default configurations are pinned and stable")
    func validatorConfigurations() {
        let cdslDefault = Presentation.CDSLValidations.cdslDefault
        #expect(cdslDefault.validationDescriptions == [
            "Dispatched actions have arguments matching their expected signature",
            "Asserted VM property names exist on the view model",
        ])

        let cllDefault = Presentation.CLLValidations.cllDefault
        #expect(cllDefault.validationDescriptions == [
            "Device profiles have consistent size classes (Mac is regular, iPhone is compact)",
            "Asserted UI property names exist on the layout mimic",
        ])
    }

    // MARK: - 4. Machinery Negative & Positive Control Tests

    @Test("CDSL Optional subject yields no errors in type-erased wrapper")
    func optionalSubjectCDSLMachinery() throws {
        let validation = Presentation.CDSLValidations.dispatchArgumentsAreCorrect
        let erased = Presentation.AnyValidation(validation)

        let optionalStmt: Presentation.CDSLProgram.Statement? = Presentation.CDSLProgram.Statement.dispatch(.selectSource, .number(42))
        let errors = try erased.apply(to: optionalStmt as Any, at: [], in: Presentation.CDSLProgram(statements: []))
        #expect(errors.isEmpty)
    }

    @Test("CLL Wrong subject type yields no errors in type-erased wrapper")
    func wrongTypeCLLMachinery() {
        let validation = Presentation.CLLValidations.deviceSizingIsConsistent
        let erased = Presentation.AnyValidation(validation)

        let errors = erased.apply(to: "Wrong type" as Any, at: [], in: Presentation.CLLProgram(statements: []))
        #expect(errors.isEmpty)
    }

    @Test("Machinery Positive Control: same wrong statement twice yields two errors")
    func positiveControlMachinery() {
        let validation = Presentation.CDSLValidations.dispatchArgumentsAreCorrect
        let erased = Presentation.AnyValidation(validation)
        let invalidStmt = Presentation.CDSLProgram.Statement.dispatch(.onAppeared, .string("not-nil"))

        let errors1 = erased.apply(to: invalidStmt, at: [Presentation.AnyCodingKey(intValue: 0)], in: Presentation.CDSLProgram(statements: [invalidStmt]))
        let errors2 = erased.apply(to: invalidStmt, at: [Presentation.AnyCodingKey(intValue: 1)], in: Presentation.CDSLProgram(statements: [invalidStmt]))
        #expect(errors1.count == 1)
        #expect(errors2.count == 1)
        #expect(errors1.first?.codingPath.map(\.stringValue) == ["0"])
        #expect(errors2.first?.codingPath.map(\.stringValue) == ["1"])
    }

    // MARK: - 5. Many-Error Assertions (Complete Error List)

    @Test("CDSL Many-error program asserts complete error list in order")
    func cdslManyErrors() {
        let validator = Presentation.CDSLValidations.cdslDefault
        let stmt1 = Presentation.CDSLProgram.Statement.dispatch(.onAppeared, .number(42)) // Error 1
        let stmt2 = Presentation.CDSLProgram.Statement.assertVM("invalidField", .eq, .string("test")) // Error 2
        let program = Presentation.CDSLProgram(statements: [stmt1, stmt2])

        let errors = validator.run(program)
        #expect(errors.count == 2)
        #expect(errors[0].code == "cdsl.dispatch.signature")
        #expect(errors[0].pathString == "[0]")
        #expect(errors[1].code == "cdsl.assert.property")
        #expect(errors[1].pathString == "[1]")
    }

    @Test("CLL Many-error program asserts complete error list in order")
    func cllManyErrors() {
        let validator = Presentation.CLLValidations.cllDefault
        let stmt1 = Presentation.CLLProgram.Statement.device(.iPhone, .portrait, .regular) // Error 1
        let stmt2 = Presentation.CLLProgram.Statement.assertUI("invalidUIField", .eq, .string("test")) // Error 2
        let program = Presentation.CLLProgram(statements: [stmt1, stmt2])

        let errors = validator.run(program)
        #expect(errors.count == 2)
        #expect(errors[0].code == "cll.device.sizing")
        #expect(errors[0].pathString == "[0]")
        #expect(errors[1].code == "cll.assert.property")
        #expect(errors[1].pathString == "[1]")
    }

    // MARK: - 6. Coverage Meta-Tests

    @Test("CDSL Coverage Meta-Test: every code in the registry is generated by at least one fixture")
    func cdslCoverage() {
        let allCodes = Presentation.CDSLValidations.allCodes
        var generatedCodes = Set<String>()
        let validator = Presentation.CDSLValidations.cdslDefault

        let fixtures: [Presentation.CDSLProgram] = [
            Presentation.CDSLProgram(statements: [
                .dispatch(.onAppeared, .string("bad")), // cdsl.dispatch.signature
            ]),
            Presentation.CDSLProgram(statements: [
                .assertVM("unknown", .eq, .nilValue), // cdsl.assert.property
            ]),
        ]

        for fix in fixtures {
            let errors = validator.run(fix)
            for err in errors {
                generatedCodes.insert(err.code)
            }
        }

        let missing = Set(allCodes).subtracting(generatedCodes)
        #expect(missing.isEmpty, "Missing CDSL test coverage for rules: \(missing)")
    }

    @Test("CLL Coverage Meta-Test: every code in the registry is generated by at least one fixture")
    func cllCoverage() {
        let allCodes = Presentation.CLLValidations.allCodes
        var generatedCodes = Set<String>()
        let validator = Presentation.CLLValidations.cllDefault

        let fixtures: [Presentation.CLLProgram] = [
            Presentation.CLLProgram(statements: [
                .device(.Mac, .landscape, .compact), // cll.device.sizing
            ]),
            Presentation.CLLProgram(statements: [
                .assertUI("unknown", .eq, .nilValue), // cll.assert.property
            ]),
        ]

        for fix in fixtures {
            let errors = validator.run(fix)
            for err in errors {
                generatedCodes.insert(err.code)
            }
        }

        let missing = Set(allCodes).subtracting(generatedCodes)
        #expect(missing.isEmpty, "Missing CLL test coverage for rules: \(missing)")
    }

    // MARK: - 7. Lexical & Syntax Recovery Tests

    @Test("CDSL Lexer panic-mode recovery: records error on bad char but keeps scanning")
    func cdslLexerRecovery() {
        var lexer = Presentation.CDSLProgram.Lexer(input: "dispatch onAppeared(nil) @ dispatch onRetried(nil)")
        let (tokens, errors) = lexer.tokenize()

        // Should have tokens for both dispatches (dispatch, onAppeared, (, nil, ), dispatch, onRetried, (, nil, ), eof)
        #expect(tokens.count == 11)
        #expect(errors.count == 1)
        #expect(errors.first?.description.contains("Unexpected character '@'") == true)
    }

    @Test("CDSL Parser panic-mode recovery: records syntax error but synchronizes to next statement")
    func cdslParserRecovery() {
        // First statement has syntax error (missing closing parenthesis)
        // Second statement is correct
        let script = "dispatch selectSource(\n assert vm activeSource == \"appleDocs\""
        var lexer = Presentation.CDSLProgram.Lexer(input: script)
        let (tokens, lexErrors) = lexer.tokenize()
        #expect(lexErrors.isEmpty)

        var parser = Presentation.CDSLProgram.Parser(tokens: tokens)
        let (program, parseErrors) = parser.parse()

        #expect(program == nil) // Fails to compile AST on errors
        #expect(parseErrors.count == 1)
        #expect(parseErrors.first?.description.contains("Expected token rparen") == true)
    }

    @Test("CLL Lexer panic-mode recovery: records error on bad char but keeps scanning")
    func cllLexerRecovery() {
        var lexer = Presentation.CLLProgram.Lexer(input: "device iPhone in portrait with compact @ device Mac in landscape with regular")
        let (tokens, errors) = lexer.tokenize()

        #expect(tokens.count == 13) // device, iPhone, in, portrait, with, compact, device, Mac, in, landscape, with, regular, eof
        #expect(errors.count == 1)
        #expect(errors.first?.description.contains("Unexpected character '@'") == true)
    }

    @Test("CLL Parser panic-mode recovery: records syntax error but synchronizes to next statement")
    func cllParserRecovery() {
        // First statement has syntax error (missing orientation and size class)
        // Second statement is correct
        let script = "device iPhone in \n assert ui device == \"Mac\""
        var lexer = Presentation.CLLProgram.Lexer(input: script)
        let (tokens, lexErrors) = lexer.tokenize()
        #expect(lexErrors.isEmpty)

        var parser = Presentation.CLLProgram.Parser(tokens: tokens)
        let (program, parseErrors) = parser.parse()

        #expect(program == nil)
        #expect(parseErrors.count == 1)
        #expect(parseErrors.first?.description.contains("Expected Orientation") == true)
    }
}
