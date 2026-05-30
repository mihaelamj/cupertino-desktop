# Cupertino Desktop

A native Apple-platform app (macOS and iOS) for browsing Apple developer documentation,
Swift Evolution, and sample code offline. On the Mac it is a thin GUI client over the
[`cupertino`](https://github.com/mihaelamj/cupertino) MCP server: it spawns
`cupertino serve` as a subprocess and talks to it over stdio via
[`SwiftMCPClient`](https://github.com/mihaelamj/SwiftMCPClient). On iOS it talks to an
in-process (embedded) backend instead of a subprocess. Either way it does not reimplement
search, indexing, crawling, or storage; the engine owns all of that.

The app reaches its backend only through a single `Backend.Documentation` protocol seam, so
nothing in the UI knows whether it is MCP over a subprocess or an in-process engine.

## Three UIs over one backend

The repo ships three UI frameworks in parallel, **SwiftUI**, **AppKit**, and **UIKit**,
over one shared backend and one set of view models, spanning three device classes,
**iPhone, iPad, and Mac**, so the approaches can be compared before a final framework
choice. SwiftUI runs on every device; AppKit is the Mac, UIKit is iPhone and iPad. The
shared view models and the backend seam are identical across all of them; only the view
code differs. See [docs/DESIGN.md](docs/DESIGN.md) and [docs/MOBILE.md](docs/MOBILE.md).

## Status

Early development. What works today, in all three UIs (SwiftUI, AppKit, UIKit) over the
shared view models:

- **Framework browser.** The sidebar lists the real frameworks (with document counts) and
  opens a framework's overview document.
- **Documentation reader.** `read_document` rendered to a full page.
- **Search.** Across the corpus, with a Docs scope (per-source, with framework and
  per-platform-minimum filters) and a unified Everything scope (docs, samples, packages
  bucketed); results open in the reader.

Backends behind the seam:

- **macOS** runs the live `Backend.LocalSubprocess` over `cupertino serve`, which implements
  `listFrameworks`, `readDocument`, `searchDocs`, and `searchEverything`
  (see [docs/PROTOCOL.md](docs/PROTOCOL.md) section 4).
- **iOS** (SwiftUI and UIKit) runs `Backend.LocalEmbedded` over a bundled real-data corpus
  captured from the cupertino index, pending the in-process `CupertinoDataEngine`.

Not yet implemented (still failing honestly behind the seam): the **sample-code browser**,
**code intelligence** (symbols, conformances, inheritance), and the real embedded engine.

Milestones are tracked in [docs/DESIGN.md](docs/DESIGN.md).

## Architecture

```
Apps (SwiftUI / AppKit / UIKit)   thin entry points; each picks a UI framework
        │
UI shells + Features              native views over shared @Observable view models
        │
Backend.Documentation             the only universal seam (AppModels value types)
        │
        ├── Backend.LocalSubprocess (macOS)   speaks MCP to a cupertino serve subprocess
        │         │
        │   SwiftMCPClient (external)          JSON-RPC over an injected transport (SwiftMCPCore)
        │         │
        │   cupertino serve                    the Homebrew binary, spawned as a subprocess
        │
        └── Backend.LocalEmbedded (iOS)        in-process; reads an embedded corpus / engine
```

Layers run one direction only: Foundation -> Infrastructure -> Features -> UI -> Apps. The
MCP client and its wire types live in the external `SwiftMCPClient` / `SwiftMCPCore`
packages; only the subprocess adapter imports them, and the UI never sees which backend
answers.

## Requirements

- macOS 15+ (the desktop apps), iOS 17+ (the mobile apps)
- Swift 6.2+
- Xcode 16+
- The [`cupertino`](https://github.com/mihaelamj/cupertino) binary (Homebrew) with a
  downloaded corpus in `~/.cupertino`, for the macOS apps. The iOS apps run over a bundled
  corpus and need no binary.

## Building

The library packages live under `Packages/`; the app targets are XcodeGen projects under
`Apps/` (the `.xcodeproj` bundles are generated, not committed).

```sh
# Build and test the packages
cd Packages
swift build
swift test

# Generate the app projects, then open the workspace and pick a scheme
cd ..
brew install xcodegen          # once
./scripts/generate-xcodeproj.sh
open Main.xcworkspace
```

Four app schemes: `CupertinoDesktopSwiftUI` and `CupertinoDesktopAppKit` run on the Mac;
`CupertinoMobileSwiftUI` and `CupertinoMobileUIKit` run on an iOS simulator or device.

## Related packages

- [`cupertino`](https://github.com/mihaelamj/cupertino) - the documentation crawler, MCP
  server, and search engine this app is a client of.
- [`SwiftMCPClient`](https://github.com/mihaelamj/SwiftMCPClient) - the transport-injectable
  MCP client.
- [`SwiftMCPCore`](https://github.com/mihaelamj/SwiftMCPCore) - the neutral MCP wire types.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The project is early, so major design decisions are
still in flight; start from [docs/DESIGN.md](docs/DESIGN.md).

## License

MIT License, see [LICENSE](LICENSE).
