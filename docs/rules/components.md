# Component System Architecture Rules

Component-system rules for the planned Tiledown native editor. The editor's UI is built from reusable, registry-driven components. This file consolidates the component protocol, the package hierarchy, the registry, and the one-component-per-file discipline.

## One component per file

- Each UI component lives in its own component package, NEVER in feature packages or screens.
- ONE component per file; the file name equals the component name.
- Every component conforms to the `Component` protocol from the `Components` package.

## Core rules

### Rule 1: Three-package hierarchy

Use this strict layering:

```
Components (core infrastructure - ZERO dependencies)
    ↓
SharedComponents (hot reload - depends on hot-reload + file-watch tools only)
    ↓
AppComponents (app-specific - depends on Components + theme + font packages)
    ↓
AllComponents (optional aggregator for previews - depends on Components + AppComponents)
```

### Rule 2: Components package foundation

Create the `Components` package FIRST with the core infrastructure:

- MUST contain: the `Component` protocol, `AnyComponent`, `ComponentsRegistry`, `ComponentFactory`.
- MUST contain: bundle management, registration interfaces, and the component-list model/view.
- MUST include a `components.json` configuration file, processed with `.process()`.
- MUST have ZERO dependencies (foundation layer).

### Rule 3: SharedComponents dependencies

Depend ONLY on hot-reload tooling:

- A hot-reload injection library and a file-watching library.
- NEVER depend on UI packages (theme, font). Mixing them in breaks the hot-reload layer's independence from the UI foundation.

### Rule 4: AppComponents dependencies

Depend on the foundation packages:

- `Components` (core system)
- The theme package (colors, styles)
- The font package (typography)

### Rule 5: Component registration

Register components via the registry:

- All components conform to the `Component` protocol from the `Components` package.
- Registration happens in a per-package `*ComponentsRegistration.swift`.
- Register external components through the shared registry.

## The Component protocol

```swift
import Foundation
import SwiftUI

public protocol ComponentData: Hashable, Decodable, Sendable {}
public typealias ComponentKind = String

public protocol Component: Sendable {
    associatedtype Data: ComponentData
    associatedtype ViewBody: View

    var data: Data { get }

    /// Build the SwiftUI view for this component.
    /// Runs on the main actor because SwiftUI view construction
    /// and state are main-actor isolated.
    @MainActor
    func make() -> ViewBody

    static var kind: ComponentKind { get }
    init(data: Data)
}

public extension Component {
    /// Auto-generates kind from the type name (e.g. "TilePreviewComponent" → "tilepreview").
    @inline(__always)
    static var kind: ComponentKind {
        let fullName = String(reflecting: Self.self)
        let parts = fullName.split(separator: ".")
        let typePath = parts.dropFirst().joined(separator: ".")
        return typePath
            .replacingOccurrences(of: "Component", with: "")
            .lowercased()
    }

    /// Register this component in the registry.
    static func register(in registry: ComponentsRegistry) {
        let componentType = Self.self
        let dataType = Self.Data.self

        registry.decoders[kind] = { decoder in
            let data = try decoder.decode(dataType, forKey: .payload)
            return ComponentFactory(data: data, type: componentType)
        }
    }
}
```

### AnyComponent (type-erased wrapper)

`AnyComponent` is a type-erased wrapper struct, not a protocol. Concrete components conform to `Component`; `AnyComponent` wraps any of them for storage and rendering.

```swift
@MainActor
public struct AnyComponent: Identifiable {
    private let component: any Component
    public var id: UUID = .init()
    public let kind: ComponentKind

    private let _make: () -> AnyView

    public init<ComponentType>(_ component: ComponentType) where ComponentType: Component {
        self.component = component
        kind = ComponentType.kind
        _make = { AnyView(component.make()) }
    }

    public var contentView: AnyView { _make() }
}
```

### ComponentFactory (Sendable bridge)

`ComponentFactory` is `Sendable` so component data can be decoded off the main thread, then rendered on the main actor.

```swift
public struct ComponentFactory: Sendable {
    public let kind: ComponentKind

    private let _makeRenderable: @MainActor () -> AnyComponent

    public init<C: Component>(data: C.Data, type: C.Type) {
        kind = C.kind
        _makeRenderable = {
            let instance = C(data: data)
            return AnyComponent(instance)
        }
    }

    @MainActor
    public func makeRenderable() -> AnyComponent {
        _makeRenderable()
    }
}
```

### ComponentsRegistry

The registry maps a component `kind` to a decoder that produces a `ComponentFactory`. JSON describing a component carries a `kind` plus a `payload`, and the registry decodes the right concrete data type.

```swift
public final class ComponentsRegistry {
    public typealias ComponentDecoder =
        @Sendable (KeyedDecodingContainer<Container.CodingKeys>) throws -> ComponentFactory

    public var decoders: [ComponentKind: ComponentDecoder] = [:]

    public struct Container: Decodable {
        public enum CodingKeys: CodingKey { case kind, payload }
        public struct ComponentNotFound: Error { public var kind: ComponentKind }
        public struct DecodersNotFound: Error {}

        public static let decodersKey = CodingUserInfoKey(rawValue: "ComponentDecoders")!
        public let factory: ComponentFactory

        public init(from decoder: Decoder) throws {
            guard let decoders = decoder.userInfo[Self.decodersKey] as? [ComponentKind: ComponentDecoder] else {
                throw DecodersNotFound()
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try container.decode(ComponentKind.self, forKey: .kind)
            guard let decodeForKind = decoders[kind] else {
                throw ComponentNotFound(kind: kind)
            }
            factory = try decodeForKind(container)
        }
    }

    public init() {}

    /// Decode JSON into ComponentFactories (safe off the main thread).
    public func decodeFactories(from data: Data) -> [ComponentFactory] {
        do {
            let decoder = JSONDecoder()
            decoder.userInfo[Container.decodersKey] = decoders
            let containers = try decoder.decode([Container].self, from: data)
            return containers.map(\.factory)
        } catch {
            print("Unable to parse \(error)")
            return []
        }
    }
}
```

## Concrete component example

One component per file. Define the data struct, store it, implement `make()`, and provide a preview.

```swift
import Components
import SwiftUI

public struct TilePreviewComponent: Component {
    public struct Data: ComponentData {
        public var title: String
        public var subtitle: String
        public var isActive: Bool = true

        public init(title: String, subtitle: String, isActive: Bool = true) {
            self.title = title
            self.subtitle = subtitle
            self.isActive = isActive
        }
    }

    public var data: Data

    public init(data: Data) {
        self.data = data
    }

    public func make() -> some View {
        TilePreviewContent(data: data)
    }
}

// Separate view struct for the actual UI.
struct TilePreviewContent: View {
    var data: TilePreviewComponent.Data
    @Environment(\.appTheme) private var theme

    var body: some View {
        // card implementation using theme.colors and the font package
        EmptyView()
    }
}

#Preview {
    TilePreviewComponent(data: .init(
        title: "Hero Tile",
        subtitle: "Top of the canvas"
    )).make()
}
```

## components.json

Describes the components and sample payloads used by previews and the component gallery. Lives in the `Components` package, processed with `.process()`.

```json
{
  "components": [
    {
      "kind": "tile-preview",
      "category": "Display",
      "description": "Displays a tile preview with status",
      "payload": {
        "title": "Hero Tile",
        "subtitle": "Top of the canvas",
        "isActive": true
      }
    }
  ]
}
```

## Registration

```swift
import Components

/// Register a package's components in the registry.
public func registerTileComponents(in registry: ComponentsRegistry) {
    TilePreviewComponent.register(in: registry)
    // additional components...
}

// In app initialization:
let registry = ComponentsRegistry()
registerTileComponents(in: registry)
```

## AllComponents aggregator

An optional umbrella package that re-exports `Components` and `AppComponents` for convenient imports.

```swift
@_exported import Components
@_exported import AppComponents
```

- USE only in preview/demo apps and the component gallery.
- DO NOT use in production features or main app targets; be explicit with imports there.

## Common mistakes

- Creating `AppComponents` without the core `Components` package.
- Adding UI dependencies (theme, font) to `Components` (it MUST have zero dependencies).
- Adding UI dependencies to `SharedComponents` (hot reload only).
- Importing the broad `AllComponents` aggregator inside production features.
- Over-specific package naming. Keep app-specific components in `AppComponents`, not a narrowly named package.

## Checklist

- [ ] `Components` package exists with zero dependencies, created first
- [ ] `Components` contains the protocol, `AnyComponent`, registry, factory, list types
- [ ] `Components` includes `components.json`, processed with `.process()`
- [ ] `SharedComponents` depends ONLY on hot-reload + file-watch tooling
- [ ] `AppComponents` depends on Components + theme + font
- [ ] `AppComponents` holds production components only
- [ ] `AllComponents`, if present, used only in preview/demo apps
- [ ] All components conform to the `Component` protocol
- [ ] ONE component per file; file name equals component name
- [ ] Registration goes through the shared registry
- [ ] Resources use `.process()` not `.copy()`
- [ ] The component layer follows the strict hierarchy
