// swift-tools-version: 6.2
import PackageDescription

// Single manifest for every library target (docs/rules/package-structure.md).
// App targets live under ../Apps as their own Xcode projects and consume this
// package through a local path dependency.
//
// Package kinds (docs/DESIGN.md section 3). A package may import only the kind
// below it:
//   API (seam)      protocols + value types only, zero concrete deps
//   Concrete        one job each; import only API packages (+ <=1 external lib);
//                   concrete packages never import each other
//   Impl (compose)  the ONLY packages allowed to import multiple concretes
//   UI / Apps       UI packages + the entry-point app targets
//
// The ONLY universal seam is `Backend.Documentation` (BackendAPI). Conformers are
// named by locality, not protocol: `Backend.LocalSubprocess` (out-of-process, talks
// to a local `cupertino serve` subprocess) and `Backend.LocalEmbedded` (in-process,
// direct calls, no MCP) are peers; a remote conformer is future. MCP is not an
// identity here: it is only the wire the subprocess conformer speaks. The MCP
// client, its transport seam, and the subprocess transport now live in the external
// `SwiftMCPClient` package (the neutral client extracted from this repo); we consume
// its `SwiftMCPClientAPI` seam above the protocol and wire the concretes in
// `MacBackendImpl`.

extension Product {
    static func singleTargetLibrary(_ name: String) -> Product {
        .library(name: name, targets: [name])
    }
}

let products: [Product] = [
    // API / seam
    .singleTargetLibrary("AppModels"),
    .singleTargetLibrary("BackendAPI"),
    .singleTargetLibrary("AppCore"),
    // Concrete
    .singleTargetLibrary("LocalSubprocessBackend"),
    .singleTargetLibrary("MarkdownRendering"),
    .singleTargetLibrary("CodeHighlighting"),
    .singleTargetLibrary("SearchFeature"),
    .singleTargetLibrary("FrameworkBrowserFeature"),
    .singleTargetLibrary("DocReaderFeature"),
    .singleTargetLibrary("SampleBrowserFeature"),
    .singleTargetLibrary("ShellSwiftUI"),
    .singleTargetLibrary("ShellAppKit"),
    .singleTargetLibrary("ShellUIKit"),
    // Concrete (Mobile path)
    .singleTargetLibrary("LocalEmbeddedBackend"),
    // Impl / composition
    .singleTargetLibrary("MacBackendImpl"),
    .singleTargetLibrary("MobileBackendImpl"),
    // UI-test support (Page Object Model + scenario engine), for the XCUITest targets.
    .singleTargetLibrary("UITestPageObjects"),
    .singleTargetLibrary("FlowSpec"),
]

// The MCP client package (external, via SwiftMCPClient): the Transport.Channel byte
// seam, the macOS subprocess transport, and the MCPClient over an injected channel,
// plus the `Client.MCP` seam, over the neutral SwiftMCPCore wire types. Replaces the
// old in-repo MCPClientKit / MCPClientAPI / TransportAPI / SubprocessTransport packages.
let kit = "SwiftMCPClient"
func kitProduct(_ name: String) -> Target.Dependency {
    .product(name: name, package: kit)
}

/// CupertinoDataKit (external, cupertino-owned): cupertino's read contract as protocols
/// + value types only. The embedded (iOS) adapter conforms a data source to its
/// `Search.DocumentReading` slice and maps results into `AppModels`. Consumed by version;
/// we never import the `cupertino` package itself.
let dataKitProduct: Target.Dependency = .product(name: "CupertinoDataKit", package: "CupertinoDataKit")

let targets: [Target] = {
    // ---------- API / seam packages (protocols + value types only) ----------
    let models = Target.target(name: "AppModels")
    let backendAPI = Target.target(name: "BackendAPI", dependencies: ["AppModels"])
    // AppCore holds the UI/Feature namespace anchors + the framework-agnostic
    // RootModel. It does not own the backend seam (that is BackendAPI).
    let core = Target.target(name: "AppCore")
    let api = [models, backendAPI, core]

    // ---------- Concrete packages (import only API packages) ----------
    // The subprocess adapter depends on the client seam (SwiftMCPClientAPI), not
    // the concrete client, so it is testable with a fake and imports no MCP wire types.
    let localSubprocessBackend = Target.target(
        name: "LocalSubprocessBackend",
        dependencies: ["BackendAPI", "AppModels", kitProduct("SwiftMCPClientAPI")],
    )
    // MarkdownRendering parses the served GFM (swift-markdown) and renders it to attributed
    // strings. swift-markdown's module is named `Markdown`; our `Markdown` namespace enum
    // shadows only the bare name, so swift-markdown's types are referenced unqualified
    // (`Document`, `Heading`) and the two coexist. Code highlighting is injected as
    // `Model.CodeHighlighting`, so this concrete keeps a single external lib and never
    // imports the highlighting concrete directly.
    let markdown = Target.target(
        name: "MarkdownRendering",
        dependencies: ["AppModels", .product(name: "Markdown", package: "swift-markdown")],
    )
    // CodeHighlighting conforms a Splash-backed highlighter to the neutral
    // `Model.CodeHighlighting` seam (in AppModels), keeping Splash as this concrete's one
    // external lib. The UI tier injects it into the renderer.
    let codeHighlighting = Target.target(
        name: "CodeHighlighting",
        dependencies: ["AppModels", .product(name: "Splash", package: "Splash")],
    )

    // ---------- Features (framework-agnostic view models) ----------
    let featureDependencies: [Target.Dependency] = ["AppCore", "AppModels", "BackendAPI", "MarkdownRendering"]
    let search = Target.target(name: "SearchFeature", dependencies: featureDependencies)
    let frameworkBrowser = Target.target(name: "FrameworkBrowserFeature", dependencies: featureDependencies)
    let docReader = Target.target(name: "DocReaderFeature", dependencies: featureDependencies)
    let sampleBrowser = Target.target(name: "SampleBrowserFeature", dependencies: featureDependencies)
    let features = [search, frameworkBrowser, docReader, sampleBrowser]

    // ---------- UI (parallel per-framework packages) ----------
    let uiDependencies: [Target.Dependency] = ["AppCore", "AppModels", "MarkdownRendering", "CodeHighlighting", "FrameworkBrowserFeature", "SearchFeature"]
    let shellSwiftUI = Target.target(name: "ShellSwiftUI", dependencies: uiDependencies)
    let shellAppKit = Target.target(name: "ShellAppKit", dependencies: uiDependencies)
    let shellUIKit = Target.target(name: "ShellUIKit", dependencies: uiDependencies)

    // The Mobile (iOS) backend conformer: a `Backend.Documentation` that reaches the
    // corpus in-process (no MCP, no subprocess), because iOS cannot spawn one. It is a
    // GoF Adapter over the injected `CupertinoDataKit.Search.DocumentReading` contract,
    // mapping that adaptee's results into `AppModels`. The read engine is a
    // constructor-injected strategy, so this adapter depends only on the named protocol,
    // never on a concrete engine or on the `cupertino` package.
    let localEmbeddedBackend = Target.target(
        name: "LocalEmbeddedBackend",
        dependencies: ["BackendAPI", "AppModels", dataKitProduct],
    )

    let concrete = [localSubprocessBackend, markdown, codeHighlighting] + features + [shellSwiftUI, shellAppKit, shellUIKit, localEmbeddedBackend]

    // ---------- Impl / composition packages (wire concretes together) ----------
    // MacBackendImpl is the only place the local-subprocess conformer, the MCP
    // client kit, and the subprocess transport meet (Desktop). MobileBackendImpl
    // composes the local-embedded conformer (Mobile). Both vend an opaque
    // `any Backend.Documentation`.
    let macBackendImpl = Target.target(
        name: "MacBackendImpl",
        dependencies: [
            "BackendAPI",
            "LocalSubprocessBackend",
            kitProduct("SwiftMCPClient"),
            kitProduct("SwiftMCPClientAPI"),
            kitProduct("SwiftMCPSubprocessTransport"),
            kitProduct("SwiftMCPTransport"),
        ],
    )
    let mobileBackendImpl = Target.target(
        name: "MobileBackendImpl",
        dependencies: ["BackendAPI", "LocalEmbeddedBackend", dataKitProduct],
        resources: [.process("Resources")],
    )
    let impl = [macBackendImpl, mobileBackendImpl]

    // ---------- UI-test support: Page Object Model (docs/rules/testing) ----------
    // A library of XCUITest page objects keyed off `UI.AccessibilityID` (in AppCore, the
    // single source of truth shared with the views). Locating elements by accessibility
    // identifier keeps each page object cross-platform: the same page drives the SwiftUI,
    // AppKit, and UIKit apps. The apps' XCUITest targets (XcodeGen) link this product.
    // FlowSpec: a dependency-free scenario engine (Verb/Step/Scenario + a StepRegistry seam
    // and a runner/loader). Scenarios are declarative JSON under `scenarios/`; a per-UI
    // registry in UITestPageObjects turns each step into a page-object action, so one
    // scenario drives the SwiftUI, AppKit, and UIKit apps.
    let flowSpec = Target.target(name: "FlowSpec")
    let uiTestPageObjects = Target.target(name: "UITestPageObjects", dependencies: ["AppCore", "FlowSpec"])

    // ---------- Tests ----------
    let coreTests = Target.testTarget(name: "AppCoreTests", dependencies: ["AppCore"])
    let frameworkBrowserTests = Target.testTarget(
        name: "FrameworkBrowserFeatureTests",
        dependencies: ["FrameworkBrowserFeature", "AppCore", "BackendAPI", "AppModels"],
    )
    let backendTests = Target.testTarget(
        name: "BackendScaffoldTests",
        dependencies: ["MacBackendImpl", "LocalSubprocessBackend", kitProduct("SwiftMCPClientAPI"), "BackendAPI", "AppModels"],
    )
    let localSubprocessTests = Target.testTarget(
        name: "LocalSubprocessBackendTests",
        dependencies: [
            "LocalSubprocessBackend",
            kitProduct("SwiftMCPClient"),
            kitProduct("SwiftMCPClientAPI"),
            kitProduct("SwiftMCPSubprocessTransport"),
            kitProduct("SwiftMCPTransport"),
            "BackendAPI",
            "AppModels",
        ],
    )

    let localEmbeddedTests = Target.testTarget(
        name: "LocalEmbeddedBackendTests",
        dependencies: ["LocalEmbeddedBackend", dataKitProduct, "BackendAPI", "AppModels"],
    )
    let searchFeatureTests = Target.testTarget(
        name: "SearchFeatureTests",
        dependencies: ["SearchFeature", "AppCore", "BackendAPI", "AppModels"],
    )
    let markdownTests = Target.testTarget(
        name: "MarkdownRenderingTests",
        dependencies: ["MarkdownRendering", "AppModels"],
    )

    return api + concrete + impl + [flowSpec, uiTestPageObjects]
        + [coreTests, frameworkBrowserTests, backendTests, localSubprocessTests, localEmbeddedTests, searchFeatureTests, markdownTests]
}()

let package = Package(
    name: "CupertinoDesktopPackages",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
    ],
    products: products,
    dependencies: [
        // The neutral MCP client package (the macOS subprocess path).
        .package(
            url: "https://github.com/mihaelamj/SwiftMCPClient.git",
            from: "0.1.0",
        ),
        // cupertino's read contract (the iOS embedded path): protocols + value types
        // only. We depend on it by version and never on the `cupertino` package itself.
        .package(
            url: "https://github.com/mihaelamj/CupertinoDataKit.git",
            from: "0.1.0",
        ),
        // GFM parser for the document renderer (the DocC parser; pure Swift, cmark-based,
        // no SwiftSyntax, no JS). Its module is named `Markdown`, which clashes with our
        // `Markdown` namespace anchor, so it is module-aliased to `MarkdownAST` below.
        .package(
            url: "https://github.com/swiftlang/swift-markdown.git",
            branch: "release/6.2",
        ),
        // Swift syntax highlighter for code blocks (pure Swift, no JS), behind the
        // `CodeHighlighting` concrete so `MarkdownRendering` keeps a single external lib.
        .package(
            url: "https://github.com/JohnSundell/Splash.git",
            from: "0.16.0",
        ),
    ],
    targets: targets,
)
