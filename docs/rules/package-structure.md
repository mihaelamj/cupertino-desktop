# Package and Repository Structure

How the repository is laid out. XCTemplateDSL is structured as a standard, single Swift Package: `Package.swift` is at the root, with multiple modular targets in the `Sources/` directory, and their corresponding test targets in `Tests/`. The `xctemplate` CLI is the main executable target.

## What this covers

XCTemplateDSL ships as one SPM package with multiple targets, not one package per library. There is a single `Package.swift` at the root; the core modules and the `xctemplate` CLI are targets within it, and new targets join the same manifest as responsibilities separate out.

Reach for additional targets in the package when one of these is true:

- A part of XCTemplateDSL becomes a clearly separable responsibility (a lexer, a parser, a validator, a decompiler) used in more than one place.
- You want isolated compilation and parallel builds across several focused targets.

## Core rules

### Rule 1: Root structure

Organize the repository with these top-level directories:

- `Package.swift` - the single package manifest at the root
- `Sources/` - all library and executable source code
- `Tests/` - all test suites
- `docs/` - documentation

### Rule 2: Single Package.swift

Use ONE `Package.swift` for all targets:

- It contains ALL library targets and products.
- It contains the CLI executable target.
- It contains ALL test targets.
- It uses `#if os()` for platform-specific targets if needed.

Do not split the targets into multiple `Package.swift` files. A single manifest keeps the dependency graph in one readable place.

### Rule 3: No storyboards or XIBs

Interface Builder artifacts are forbidden:

- NO `.storyboard` files.
- NO `.xib` files.
- All UI, if ever added in the future, is created in code (SwiftUI or programmatic UIKit/AppKit).

## Directory structure

```
XCTemplateDSL/
├── Package.swift                  # ALL targets defined here
├── Package.resolved
├── README.md
├── LICENSE
├── Sources/
│   ├── xctemplate/             # the xctemplate CLI executable target
│   ├── SharedModels/             # shared compiler and AST models
│   ├── Lexer/                    # DSL lexer
│   ├── Parser/                   # DSL parser
│   ├── Decompiler/               # template decompiler
│   ├── PackManager/              # bundle pack manager
│   ├── TemplateExpander/         # template expander
│   └── Validation/               # OpenAPIKit-style validator
└── Tests/
    ├── DSLCompilerTests/
    ├── LexerTests/
    ├── ParserTests/
    └── ...
```

## Package.swift structure (many targets in one package)

Use helper-driven, grouped target declarations rather than one giant inline array.

### Target organization pattern

```swift
let targets: [Target] = {
    // ---------- Shared Models ----------
    let sharedModelsTarget = Target.target(
        name: "SharedModels",
        dependencies: []
    )
    
    // ---------- Lexer ----------
    let lexerTarget = Target.target(
        name: "Lexer",
        dependencies: []
    )

    // ---------- Parser ----------
    let parserTarget = Target.target(
        name: "Parser",
        dependencies: [
            "Lexer",
            "SharedModels",
        ]
    )

    // ...
    
    return [sharedModelsTarget, lexerTarget, parserTarget, ...]
}()
```

## Common mistakes

- Do NOT create multiple `Package.swift` files, one per library. Use a single manifest.
- Do NOT keep `.storyboard` or `.xib` files anywhere.

## Checklist

Before changing repo structure:

- [ ] Single SPM package manifest at the root
- [ ] All library and CLI code under `Sources/`
- [ ] All test code under `Tests/`
- [ ] Platform-specific targets use `#if os()`
- [ ] No `.storyboard` or `.xib` files anywhere

## Related rules

- [package-architecture.md](package-architecture.md): single-responsibility targets, layers, and the when-to-create decision tree
- [package-import-contract.md](package-import-contract.md): what each target may import
- [shared-protocols.md](shared-protocols.md): the cross-target protocol-seam package
