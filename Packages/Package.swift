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
// `CupertinoMCPClientKit` package (the client extracted from this repo); we consume
// its `CupertinoMCPClientAPI` seam above the protocol and wire the concretes in
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

// The MCP client kit (external, local path): wire core, the Transport.Channel byte
// seam, the macOS subprocess transport, and the MCPClient over an injected channel,
// plus the `Client.MCP` seam. Replaces the old in-repo MCPClientKit / MCPClientAPI /
// TransportAPI / SubprocessTransport packages.
let kit = "CupertinoMCPClientKit"
func kitProduct(_ name: String) -> Target.Dependency {
    .product(name: name, package: kit)
}

let targets: [Target] = {
    // ---------- API / seam packages (protocols + value types only) ----------
    let models = Target.target(name: "AppModels")
    let backendAPI = Target.target(name: "BackendAPI", dependencies: ["AppModels"])
    // AppCore holds the UI/Feature namespace anchors + the framework-agnostic
    // RootModel. It does not own the backend seam (that is BackendAPI).
    let core = Target.target(name: "AppCore")
    let api = [models, backendAPI, core]

    // ---------- Concrete packages (import only API packages) ----------
    // The subprocess adapter depends on the client seam (CupertinoMCPClientAPI), not
    // the concrete client, so it is testable with a fake and imports no MCP wire types.
    let localSubprocessBackend = Target.target(
        name: "LocalSubprocessBackend",
        dependencies: ["BackendAPI", "AppModels", kitProduct("CupertinoMCPClientAPI")],
    )
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

    let concrete = [localSubprocessBackend, markdown] + features + [shellSwiftUI, shellAppKit, localEmbeddedBackend]

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
            kitProduct("CupertinoMCPClient"),
            kitProduct("CupertinoMCPClientAPI"),
            kitProduct("CupertinoMCPSubprocessTransport"),
            kitProduct("CupertinoMCPTransport"),
        ],
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
        dependencies: ["MacBackendImpl", "LocalSubprocessBackend", kitProduct("CupertinoMCPClientAPI"), "BackendAPI", "AppModels"],
    )
    let localSubprocessTests = Target.testTarget(
        name: "LocalSubprocessBackendTests",
        dependencies: [
            "LocalSubprocessBackend",
            kitProduct("CupertinoMCPClient"),
            kitProduct("CupertinoMCPClientAPI"),
            kitProduct("CupertinoMCPSubprocessTransport"),
            kitProduct("CupertinoMCPTransport"),
            "BackendAPI",
            "AppModels",
        ],
    )

    return api + concrete + impl + [coreTests, backendTests, localSubprocessTests]
}()

let package = Package(
    name: "CupertinoDesktopPackages",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
    ],
    products: products,
    dependencies: [
        // The extracted MCP client kit. Local path: this repo is the kit's first
        // consumer; both are public siblings. From this manifest's root (Packages/)
        // the kit is two levels up.
        .package(name: "CupertinoMCPClientKit", path: "../../CupertinoMCPClientKit"),
        // Local path to the cupertino monorepo's package, via the `CupertinoUpstream`
        // symlink (-> ../../cupertino/Packages) so the path-dependency identity is
        // unique. Kept for the FUTURE in-process embedded path (Mobile); the
        // subprocess path no longer depends on cupertino's `MCPCore`.
        .package(name: "Cupertino", path: "CupertinoUpstream"),
    ],
    targets: targets,
)
