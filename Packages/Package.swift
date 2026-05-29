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
// identity here: it is only the wire the subprocess conformer's client (MCPClientKit)
// speaks, reusing cupertino's cross-platform `MCPCore` types.

extension Product {
    static func singleTargetLibrary(_ name: String) -> Product {
        .library(name: name, targets: [name])
    }
}

let products: [Product] = [
    // API / seam
    .singleTargetLibrary("AppModels"),
    .singleTargetLibrary("BackendAPI"),
    .singleTargetLibrary("MCPClientAPI"),
    .singleTargetLibrary("TransportAPI"),
    .singleTargetLibrary("AppCore"),
    // Concrete
    .singleTargetLibrary("MCPClientKit"),
    .singleTargetLibrary("SubprocessTransport"),
    .singleTargetLibrary("LocalSubprocessBackend"),
    .singleTargetLibrary("MarkdownRendering"),
    .singleTargetLibrary("SearchFeature"),
    .singleTargetLibrary("FrameworkBrowserFeature"),
    .singleTargetLibrary("DocReaderFeature"),
    .singleTargetLibrary("SampleBrowserFeature"),
    .singleTargetLibrary("ShellSwiftUI"),
    .singleTargetLibrary("ShellAppKit"),
    // Concrete (Mobile path)
    .singleTargetLibrary("LocalEmbeddedBackend"),
    // Impl / composition
    .singleTargetLibrary("MacBackendImpl"),
    .singleTargetLibrary("MobileBackendImpl"),
]

let targets: [Target] = {
    // ---------- API / seam packages (protocols + value types only) ----------
    let models = Target.target(name: "AppModels")
    let backendAPI = Target.target(name: "BackendAPI", dependencies: ["AppModels"])
    let transportAPI = Target.target(name: "TransportAPI")
    // The MCP client contract, in our own types (no MCPCore). Lets LocalSubprocessBackend
    // depend on a protocol instead of the concrete MCPClientKit, so Backend.LocalSubprocess
    // is testable with a fake and concrete packages stop importing each other.
    let clientAPI = Target.target(name: "MCPClientAPI")
    // AppCore holds the UI/Feature namespace anchors + the framework-agnostic
    // RootModel. It does not own the backend seam (that is BackendAPI).
    let core = Target.target(name: "AppCore")
    let api = [models, backendAPI, transportAPI, clientAPI, core]

    // ---------- Concrete packages (import only API packages) ----------
    // The MCP client reuses cupertino's cross-platform MCPCore protocol types.
    let clientKit = Target.target(
        name: "MCPClientKit",
        dependencies: ["MCPClientAPI", "TransportAPI", .product(name: "MCPCore", package: "Cupertino")],
    )
    let subprocessTransport = Target.target(name: "SubprocessTransport", dependencies: ["TransportAPI"])
    let localSubprocessBackend = Target.target(name: "LocalSubprocessBackend", dependencies: ["BackendAPI", "AppModels", "MCPClientAPI"])
    let markdown = Target.target(name: "MarkdownRendering", dependencies: ["AppModels"])

    // ---------- Features (framework-agnostic view models) ----------
    let featureDependencies: [Target.Dependency] = ["AppCore", "BackendAPI", "MarkdownRendering"]
    let search = Target.target(name: "SearchFeature", dependencies: featureDependencies)
    let frameworkBrowser = Target.target(name: "FrameworkBrowserFeature", dependencies: featureDependencies)
    let docReader = Target.target(name: "DocReaderFeature", dependencies: featureDependencies)
    let sampleBrowser = Target.target(name: "SampleBrowserFeature", dependencies: featureDependencies)
    let features = [search, frameworkBrowser, docReader, sampleBrowser]

    // ---------- UI (parallel per-framework packages) ----------
    let uiDependencies: [Target.Dependency] = ["AppCore", "MarkdownRendering"]
    let shellSwiftUI = Target.target(name: "ShellSwiftUI", dependencies: uiDependencies)
    let shellAppKit = Target.target(name: "ShellAppKit", dependencies: uiDependencies)

    // The Mobile (iOS) backend conformer: a `Backend.Documentation` that reaches
    // cupertino in-process (no MCP, no subprocess), because iOS cannot spawn one.
    // Direct cupertino calls land in a later milestone; this scaffold fixes shape.
    let localEmbeddedBackend = Target.target(name: "LocalEmbeddedBackend", dependencies: ["BackendAPI", "AppModels"])

    let concrete = [clientKit, subprocessTransport, localSubprocessBackend, markdown] + features + [shellSwiftUI, shellAppKit, localEmbeddedBackend]

    // ---------- Impl / composition packages (wire concretes together) ----------
    // MacBackendImpl is the only place the local-subprocess conformer, its MCP
    // client, and the subprocess transport meet (Desktop). MobileBackendImpl
    // composes the local-embedded conformer (Mobile). Both vend an opaque
    // `any Backend.Documentation`.
    let macBackendImpl = Target.target(
        name: "MacBackendImpl",
        dependencies: ["BackendAPI", "LocalSubprocessBackend", "MCPClientAPI", "MCPClientKit", "TransportAPI", "SubprocessTransport"],
    )
    let mobileBackendImpl = Target.target(
        name: "MobileBackendImpl",
        dependencies: ["BackendAPI", "LocalEmbeddedBackend"],
    )
    let impl = [macBackendImpl, mobileBackendImpl]

    // ---------- Tests ----------
    let coreTests = Target.testTarget(name: "AppCoreTests", dependencies: ["AppCore"])
    let backendTests = Target.testTarget(
        name: "BackendScaffoldTests",
        dependencies: ["MacBackendImpl", "LocalSubprocessBackend", "MCPClientAPI", "BackendAPI", "AppModels"],
    )

    return api + concrete + impl + [coreTests, backendTests]
}()

let package = Package(
    name: "CupertinoDesktopPackages",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
    ],
    products: products,
    dependencies: [
        // Local path to the cupertino monorepo's package. cupertino is an
        // ExtremePackaging layout, so its manifest is under Packages/, but that
        // basename collides with ours (SwiftPM derives a path dependency's
        // identity from its directory basename). We point at the
        // `CupertinoUpstream` symlink (-> ../../cupertino/Packages) so the
        // identity is unique. We only link its cross-platform `MCPCore` product.
        // See docs/DESIGN.md open question 5.
        .package(name: "Cupertino", path: "CupertinoUpstream"),
    ],
    targets: targets,
)
