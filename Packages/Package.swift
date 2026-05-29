// swift-tools-version: 6.2
import PackageDescription

// Single manifest for every library target (docs/rules/package-structure.md).
// App targets live under ../Apps as their own Xcode projects and consume this
// package through a local path dependency.
//
// Layers run one direction only:
//   Foundation (DesktopModels, DesktopCore)
//     -> Infrastructure (MCPBackend, MarkdownRendering)
//     -> Features (UI-agnostic @Observable view models)
//     -> UI seam (DesktopUI: the protocols both frameworks implement)
//     -> UI implementations (one AppKit package + one SwiftUI package per
//        feature, plus a combined "flow" package per framework)
//
// The AppKit and SwiftUI sides implement the SAME protocols from DesktopUI, so
// the app targets consume either side identically; only the injected conformer
// differs.

extension Product {
    static func singleTargetLibrary(_ name: String) -> Product {
        .library(name: name, targets: [name])
    }
}

let products: [Product] = [
    // Foundation / Infrastructure
    .singleTargetLibrary("DesktopModels"),
    .singleTargetLibrary("DesktopCore"),
    .singleTargetLibrary("MCPBackend"),
    .singleTargetLibrary("MarkdownRendering"),
    // Features (logic only)
    .singleTargetLibrary("SearchFeature"),
    .singleTargetLibrary("FrameworkBrowserFeature"),
    .singleTargetLibrary("DocReaderFeature"),
    .singleTargetLibrary("SampleBrowserFeature"),
    // UI seam
    .singleTargetLibrary("DesktopUI"),
    // UI implementations (per framework)
    .singleTargetLibrary("SearchAppKit"),
    .singleTargetLibrary("SearchSwiftUI"),
    // Combined flows (per framework)
    .singleTargetLibrary("AppKitFlow"),
    .singleTargetLibrary("SwiftUIFlow"),
]

let targets: [Target] = {
    // ---------- Foundation Layer ----------
    let models = Target.target(name: "DesktopModels")
    let core = Target.target(name: "DesktopCore", dependencies: ["DesktopModels"])
    let foundation = [models, core]

    // ---------- Infrastructure Layer ----------
    // MCPBackend is the only target that will import the `cupertino` package
    // (wired in milestone M1); everything above it sees the backend seam only.
    let mcpBackend = Target.target(name: "MCPBackend", dependencies: ["DesktopCore"])
    let markdown = Target.target(name: "MarkdownRendering", dependencies: ["DesktopModels"])
    let infrastructure = [mcpBackend, markdown]

    // ---------- Features Layer (UI-agnostic view models) ----------
    let search = Target.target(name: "SearchFeature", dependencies: ["DesktopCore"])
    let frameworkBrowser = Target.target(name: "FrameworkBrowserFeature", dependencies: ["DesktopCore"])
    let docReader = Target.target(name: "DocReaderFeature", dependencies: ["DesktopCore"])
    let sampleBrowser = Target.target(name: "SampleBrowserFeature", dependencies: ["DesktopCore"])
    let features = [search, frameworkBrowser, docReader, sampleBrowser]

    // ---------- UI Seam ----------
    // The protocols both frameworks implement, plus the platform typealias and a
    // small SwiftUI<->AppKit controller bridge.
    let desktopUI = Target.target(
        name: "DesktopUI",
        dependencies: [
            "DesktopModels",
            "SearchFeature",
            "FrameworkBrowserFeature",
            "DocReaderFeature",
            "SampleBrowserFeature",
        ],
        path: "Sources/Desktop/Seam",
    )

    // ---------- UI Implementations ----------
    // One package per feature per framework. Both conform to the same DesktopUI
    // protocol for that feature. Milestone M0 wires Search end to end; the other
    // three features follow the identical pattern.
    let searchAppKit = Target.target(
        name: "SearchAppKit",
        dependencies: ["DesktopUI", "SearchFeature"],
        path: "Sources/Desktop/AppKit/Search",
    )
    let searchSwiftUI = Target.target(
        name: "SearchSwiftUI",
        dependencies: ["DesktopUI", "SearchFeature"],
        path: "Sources/Desktop/SwiftUI/Search",
    )

    // ---------- Combined Flows ----------
    // The "start a flow" packages: each assembles its framework's screens into a
    // root controller behind the shared DesktopUI.Flow protocol.
    let appKitFlow = Target.target(
        name: "AppKitFlow",
        dependencies: ["DesktopUI", "SearchAppKit"],
        path: "Sources/Desktop/AppKit/Flow",
    )
    let swiftUIFlow = Target.target(
        name: "SwiftUIFlow",
        dependencies: ["DesktopUI", "SearchSwiftUI"],
        path: "Sources/Desktop/SwiftUI/Flow",
    )
    let userInterface = [desktopUI, searchAppKit, searchSwiftUI, appKitFlow, swiftUIFlow]

    // ---------- Tests ----------
    let coreTests = Target.testTarget(name: "DesktopCoreTests", dependencies: ["DesktopCore"])

    return foundation + infrastructure + features + userInterface + [coreTests]
}()

let package = Package(
    name: "CupertinoDesktopPackages",
    platforms: [
        .macOS(.v15),
    ],
    products: products,
    targets: targets,
)
