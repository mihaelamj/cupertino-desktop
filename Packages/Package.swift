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
// The ONLY universal backend seam is `Backend.Documentation` (BackendAPI). MCP
// is confined to one conformer (`Backend.MCP` + MCPClientKit + the Transport
// packages); the future embedded backend reaches cupertino directly with no MCP.
// We reuse cupertino's cross-platform `MCPCore` types, nothing macOS-gated.

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
    .singleTargetLibrary("MCPBackend"),
    .singleTargetLibrary("MarkdownRendering"),
    .singleTargetLibrary("SearchFeature"),
    .singleTargetLibrary("FrameworkBrowserFeature"),
    .singleTargetLibrary("DocReaderFeature"),
    .singleTargetLibrary("SampleBrowserFeature"),
    .singleTargetLibrary("ShellSwiftUI"),
    .singleTargetLibrary("ShellAppKit"),
    // Impl / composition
    .singleTargetLibrary("MacBackendImpl"),
]

let targets: [Target] = {
    // ---------- API / seam packages (protocols + value types only) ----------
    let models = Target.target(name: "AppModels")
    let backendAPI = Target.target(name: "BackendAPI", dependencies: ["AppModels"])
    let transportAPI = Target.target(name: "TransportAPI")
    // The MCP client contract, in our own types (no MCPCore). Lets MCPBackend
    // depend on a protocol instead of the concrete MCPClientKit, so Backend.MCP
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
    let mcpBackend = Target.target(name: "MCPBackend", dependencies: ["BackendAPI", "AppModels", "MCPClientAPI"])
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

    let concrete = [clientKit, subprocessTransport, mcpBackend, markdown] + features + [shellSwiftUI, shellAppKit]

    // ---------- Impl / composition packages (wire concretes together) ----------
    // The only place the MCP conformer, the client, and the transport meet.
    let macBackendImpl = Target.target(
        name: "MacBackendImpl",
        dependencies: ["BackendAPI", "MCPBackend", "MCPClientAPI", "MCPClientKit", "TransportAPI", "SubprocessTransport"],
    )
    let impl = [macBackendImpl]

    // ---------- Tests ----------
    let coreTests = Target.testTarget(name: "AppCoreTests", dependencies: ["AppCore"])
    let backendTests = Target.testTarget(
        name: "BackendScaffoldTests",
        dependencies: ["MacBackendImpl", "MCPBackend", "MCPClientAPI", "BackendAPI", "AppModels"],
    )

    return api + concrete + impl + [coreTests, backendTests]
}()

let package = Package(
    name: "CupertinoDesktopPackages",
    platforms: [
        .macOS(.v15),
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
