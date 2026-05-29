# Package and Repository Structure

How the repository is laid out. Tiledown is a monorepo from day one: a workspace, a single `Package.swift` under `Packages/`, many single-responsibility targets in that one package, and `Apps/` for app targets. Sources live in `Packages/Sources/`, tests in `Packages/Tests/`. The `TileKit` library and the `tile-down` executable are already two targets in that package, so the layout rules below apply now.

## What this covers

Tiledown ships as one SPM package with many targets, not one package per library. There is a single `Package.swift` under `Packages/`; the `TileKit` library and the `tile-down` CLI are two targets in it today, and new targets join the same manifest as responsibilities separate out. The workspace and `Apps/` directory are part of the structure from the start; `Apps/` holds app targets (such as the planned native macOS/iOS editor) while the CLI executable target stays in `Package.swift`.

Reach for additional targets in the single package when one of these is true:

- A part of TileKit becomes a clearly separable responsibility (a parser, a transport, a renderer) used in more than one place.
- A second app target appears (for example the GUI editor alongside the CLI).
- You want isolated compilation and parallel builds across several focused targets.

## Core rules

### Rule 1: Root structure

Organize the repository with these top-level directories:

- `Main.xcworkspace` containing all projects
- `Packages/` for the single SPM package with all library and CLI targets
- `Apps/` for app targets that ship a UI (such as the planned native editor)
- `docs/` for documentation

The workspace hosts the `Packages/` SPM package and any `Apps/*/*.xcodeproj`. The CLI executable target stays inside the single `Package.swift`; `Apps/` is for app targets that need Xcode project settings a plain SPM executable target cannot express.

### Rule 2: Single Package.swift

Use ONE `Package.swift` for all targets:

- It contains ALL library targets and products.
- It contains the CLI executable target.
- It contains ALL test targets.
- It uses `#if os()` for platform-specific targets.
- App projects reference the package via a local path dependency.

Do not split the targets into one `Package.swift` per library. A single manifest keeps the dependency graph in one readable place.

### Rule 3: Apps as separate projects

App targets (such as the planned native macOS/iOS editor) are separate Xcode projects in `Apps/`:

- Each app has its own `.xcodeproj`.
- Apps import the package as a local SPM dependency.
- This enables different app configurations (Debug, Release, alternate backends).
- It supports multiple platforms per app.

The CLI executable target stays inside the single `Package.swift`. Use `Apps/` for app targets that need Xcode project settings a plain SPM executable target cannot express.

### Rule 4: Workspace references

Add every project to the workspace: the `Packages/` SPM package, each `Apps/*/*.xcodeproj`, and the docs/README files.

### Rule 5: No storyboards or XIBs

For any UI you add, do not use Interface Builder artifacts:

- NO `.storyboard` files.
- NO `.xib` files.
- ALL UI is created in code (SwiftUI or programmatic UIKit/AppKit).
- Delete any auto-generated storyboards from Xcode templates.

### Rule 6: UI code lives in packages

Keep views and view controllers in packages, not in app targets:

- SwiftUI views in feature packages.
- UIKit/AppKit views in a dedicated UI package.
- App targets contain ONLY entry points (`AppDelegate`, `SceneDelegate`, `@main`).

## Directory structure

```
TileDownRoot/
├── Main.xcworkspace/              # Hosts the package and any Apps/ projects
│   └── contents.xcworkspacedata
├── Packages/                      # Single SPM package
│   ├── Package.swift              # ALL targets defined here
│   ├── Package.resolved
│   ├── Sources/
│   │   ├── TileKit/               # the engine library
│   │   ├── TileDownCLI/           # the tile-down CLI target
│   │   └── ...                    # additional focused libraries
│   └── Tests/
│       ├── TileKitTests/
│       └── ...
├── Apps/                          # App targets (planned native editor)
│   └── TileDownApp/
│       ├── TileDownApp.xcodeproj/
│       └── TileDownApp/
├── docs/
└── README.md
```

## Package.swift structure (many targets in one package)

Use helper-driven, grouped target declarations rather than one giant inline array.

### Platform-specific products

```swift
// swift-tools-version: 6.0
import PackageDescription

// ---------- Base Products (All Platforms) ----------
let baseProducts: [Product] = [
    .singleTargetLibrary("TileKit"),
    .singleTargetLibrary("TileCore"),
    .executable(name: "tile-down", targets: ["TileDownCLI"]),
]

// ---------- Apple-Only Products ----------
#if os(iOS) || os(macOS)
let appleOnlyProducts: [Product] = [
    .singleTargetLibrary("TileUI"),
]
#else
let appleOnlyProducts: [Product] = []
#endif

let allProducts = baseProducts + appleOnlyProducts

extension Product {
    static func singleTargetLibrary(_ name: String) -> Product {
        .library(name: name, targets: [name])
    }
}
```

### Target organization pattern

```swift
let targets: [Target] = {
    // ---------- Foundation Layer ----------
    let tileCoreTarget = Target.target(
        name: "TileCore",
        dependencies: []
    )
    let tileCoreTestsTarget = Target.testTarget(
        name: "TileCoreTests",
        dependencies: ["TileCore"]
    )
    let foundationTargets = [tileCoreTarget, tileCoreTestsTarget]

    // ---------- Library Layer ----------
    let tileKitTarget = Target.target(
        name: "TileKit",
        dependencies: ["TileCore"]
    )
    let libraryTargets = [tileKitTarget]

    return foundationTargets + libraryTargets
}()
```

## App configuration (only if a GUI app is added)

### Removing storyboard references

When you create a new Xcode app project, remove all storyboard configuration.

iOS (UIKit):

1. Delete `Main.storyboard` and `LaunchScreen.storyboard`.
2. Remove the `UIMainStoryboardFile` and `UILaunchStoryboardName` keys from `Info.plist`.
3. Configure the scene manifest with a `UISceneDelegateClassName` and no `UISceneStoryboardFile` key.
4. Provide a launch screen via the `UILaunchScreen` plist dictionary instead of a storyboard.
5. Clear the storyboard build-setting fields.

macOS (AppKit):

1. Delete `Main.storyboard` / `MainMenu.xib`.
2. Remove `NSMainStoryboardFile` and `NSMainNibFile` from `Info.plist`.
3. Set `NSPrincipalClass` to `NSApplication`.
4. Clear the Main Interface build setting.
5. Provide a `main.swift` (AppKit without a storyboard needs an explicit entry point, no `@main`):

```swift
import Cocoa

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
```

macOS (SwiftUI):

1. Delete any `.storyboard` / `.xib` files.
2. Use a `@main` `App` struct. No storyboard keys are needed.

### Build menus in code

For AppKit apps, build the `NSMenu` programmatically in the app delegate rather than using `MainMenu.xib`.

## Native UI patterns (AppKit / UIKit)

If you add a UIKit/AppKit UI package, use platform typealiases and factory entry points so the app target stays minimal:

```swift
#if os(macOS)
import AppKit
public typealias PlatformViewController = NSViewController
public typealias PlatformView = NSView
public typealias PlatformColor = NSColor
#elseif os(iOS)
import UIKit
public typealias PlatformViewController = UIViewController
public typealias PlatformView = UIView
public typealias PlatformColor = UIColor
#endif
```

```swift
public enum NativeUI {
    #if os(macOS)
    @MainActor
    public static func createWindowController() -> NSWindowController {
        NativeWindowController()
    }
    #endif
}
```

The app target then just wires the factory:

```swift
// SceneDelegate (iOS)
window = NativeUI.createMainWindow(for: windowScene)  // all UI from the package
```

## When to create a new app target

Create a new app target when:

- A different backend endpoint is needed (local, staging, production).
- A different platform is targeted (iOS, macOS).
- A different app variant ships (lite, pro).
- A different testing mode is needed (offline, mock data).

Do NOT create a new app target when:

- You only need Debug vs Release (use build configurations).
- You only need a different bundle ID (use build settings).
- You only have a feature-flag difference (use runtime flags).

## Common mistakes

- Do NOT put app executable targets for shipping GUI apps in `Package.swift` when they need real Xcode project settings. (A plain CLI executable target is fine in `Package.swift`.)
- Do NOT create multiple `Package.swift` files, one per library. Use a single manifest.
- Do NOT put business logic, view models, services, or models in an app target. They belong in targets under `Packages/Sources/`.
- Do NOT keep `.storyboard` or `.xib` files anywhere.
- Do NOT keep view controllers in the app target. Move them into a package.

## Checklist

Before changing repo structure:

- [ ] Single SPM package manifest for all targets
- [ ] All library and CLI code under `Packages/Sources/`
- [ ] All test code under `Packages/Tests/`
- [ ] Each GUI app, if any, is a separate `.xcodeproj` in `Apps/`
- [ ] Apps import the package via a local dependency
- [ ] Platform-specific targets use `#if os()`
- [ ] App targets contain entry points only
- [ ] Business logic stays in packages, not apps
- [ ] No `.storyboard` or `.xib` files anywhere
- [ ] macOS AppKit apps have `main.swift` (not `@main`)
- [ ] SwiftUI apps use a `@main` `App` struct

## Related rules

- [package-architecture.md](package-architecture.md): single-responsibility packages, layers, and the when-to-create decision tree
- [package-import-contract.md](package-import-contract.md): what each target may import
- [shared-protocols.md](shared-protocols.md): the cross-target protocol-seam package
