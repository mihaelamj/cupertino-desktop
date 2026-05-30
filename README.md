# Cupertino Desktop

A native macOS app for browsing Apple developer documentation, Swift Evolution, and
sample code offline. It is a thin GUI client over the
[`cupertino`](https://github.com/mihaelamj/cupertino) MCP server: it spawns
`cupertino serve` as a subprocess and talks to it over stdio via
[`SwiftMCPClient`](https://github.com/mihaelamj/SwiftMCPClient). It does not reimplement
search, indexing, crawling, or storage; the server owns all of that.

The app reaches the server only through a single `Backend.Documentation` protocol seam, so
nothing in the UI knows it is MCP over a subprocess.

## Two UIs over one backend

The repo ships two macOS app targets in parallel, **SwiftUI** and **AppKit**, over one
shared backend, so the two approaches can be compared before a final framework choice. The
shared view models and the backend seam are identical; only the view code differs. A native
iOS variant over an in-process (embedded) backend is planned. See
[docs/DESIGN.md](docs/DESIGN.md) and [docs/MOBILE.md](docs/MOBILE.md).

## Status

Early development. What works today:

- **Framework browser.** The sidebar lists the real frameworks (with document counts) from
  the live backend, in both the SwiftUI and AppKit apps, over one shared view model.

Scaffolded behind the backend seam but not yet implemented:

- **Documentation reader** (`read_document` to a rendered page).
- **Search** across the corpus.
- **Sample code browser.**
- The **iOS variants** and the embedded (in-process) backend.

Milestones are tracked in [docs/DESIGN.md](docs/DESIGN.md).

## Architecture

```
Apps (SwiftUI / AppKit)        thin entry points, one UI variant + one backend each
        │
UI shells + Features           native views over shared @Observable view models
        │
Backend.Documentation          the only universal seam (AppModels value types)
        │
Backend.LocalSubprocess        the macOS adapter; speaks MCP to a cupertino serve subprocess
        │
SwiftMCPClient (external)       JSON-RPC over an injected transport (over SwiftMCPCore)
        │
cupertino serve                the Homebrew binary, spawned as a subprocess
```

Layers run one direction only: Foundation -> Infrastructure -> Features -> UI -> Apps. The
MCP client and its wire types live in the external `SwiftMCPClient` / `SwiftMCPCore`
packages; only the subprocess adapter imports them, and the UI never sees MCP.

## Requirements

- macOS 15+
- Swift 6.2+
- Xcode 16+
- The [`cupertino`](https://github.com/mihaelamj/cupertino) binary (Homebrew) with a
  downloaded corpus in `~/.cupertino`.

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
open Main.xcworkspace           # run CupertinoDesktopSwiftUI or CupertinoDesktopAppKit
```

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
