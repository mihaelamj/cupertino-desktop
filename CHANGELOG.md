# Changelog

All notable changes to CupertinoDesktop are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `MobileBackendImpl` now depends on the published `CupertinoDataEngine` package and
  exposes `MobileBackend.live(engine:)`, injecting the engine itself as the composed
  `Search.DocumentReading` / `Search.SymbolReading` facade while borrowing optional sample
  and package reader slices from it. UI packages still receive only
  `Backend.Documentation`; DB paths and concrete storage readers remain inside
  Cupertino-owned composition.
- `Backend.LocalEmbedded` now consumes CupertinoDataKit sample and symbol reader
  slices (`Sample.Index.Reader`, `Search.SymbolReading`) in addition to
  `Search.DocumentReading`, so embedded targets can use samples and code-intelligence
  commands without exposing storage details to the desktop app. Embedded package search
  still fails honestly until CupertinoDataKit publishes a package-reader contract.
- `PresentationBridge`, a framework-neutral presentation layer between native
  shells and feature view models. It currently owns reusable load state and the
  logical Docs-scope search result tree, with tests and GitHub-rendered Mermaid
  diagrams in the README.
- M0 skeleton: the `Packages/` SPM package with the layered target tree, both
  `Apps/` targets (SwiftUI and AppKit) generated from XcodeGen `project.yml`, and
  `Main.xcworkspace`. The UI ships as parallel native packages `ShellSwiftUI` /
  `ShellAppKit` (no NSHostingController or representable bridges) exposing a
  same-shaped `UI.RootExperience` over one shared, UI-framework-free
  `UI.RootModel`, so each app consumes its framework identically. Launches an
  empty split-view shell.
- Backend seam scaffold: a transport-agnostic, protocol-only package graph. The
  ONLY universal seam is `Backend.Documentation` (`BackendAPI`); conformers are
  named by locality, not protocol. `Backend.LocalSubprocess` (`LocalSubprocessBackend`)
  talks JSON-RPC via its `MCPClient` (`MCPClientKit`, reusing cupertino's
  cross-platform `MCPCore` types) over a `Transport.Channel` (`TransportAPI`), with
  `Transport.Subprocess` (`SubprocessTransport`) spawning `cupertino serve`.
  `MacBackendImpl` is the composition root wiring those together. MCP is not an
  identity: it is only the wire that conformer's client speaks. Real value types in
  `AppModels`. Method bodies are honest M1 placeholders (throw, never fake).
- `scripts/generate-xcodeproj.sh` to materialize the per-app Xcode projects from
  their `project.yml` manifests.
- Mobile (iOS) scaffold: the package now targets iOS 17 alongside macOS 15. New
  `CupertinoMobile` iOS app reuses the `ShellSwiftUI` shell and `AppCore` through
  the same `UI.RootExperience` seam as the macOS SwiftUI app. New
  `LocalEmbeddedBackend` (`Backend.LocalEmbedded`, in-process cupertino, no
  MCP/subprocess) and `MobileBackendImpl` (`MobileBackend.live`) mirror the Mac path
  under the shared `Backend.Documentation` seam. Bodies are honest M1 placeholders.

### Changed

- Docs-scope search results group by framework in all three shells (SwiftUI sections,
  AppKit group rows, UIKit section headers), reifying the shared `Feature.Search`
  `docsTree` / `ResultNode` data. Closes #51.
- Renamed the shared, platform-agnostic packages `DesktopModels` → `AppModels`
  and `DesktopCore` → `AppCore` (they serve both Desktop and Mobile, so the
  `Desktop` prefix was a misnomer); `Desktop`/`Mobile` now name only the platform
  shells and apps.
- Introduced `MCPClientAPI` (`Client.MCP`, `Client.Argument`): a dependency-free
  client seam in our own types. `MCPBackend` now depends on this protocol instead
  of the concrete `MCPClientKit`, so `Backend.MCP` is unit-testable with a fake
  client and concrete packages no longer import each other.
- Renamed `MCPTransportAPI` → `TransportAPI`: the transport carries opaque frames
  with no MCP types of its own, so the `MCP` prefix was a misnomer.
- Renamed the backend conformers by locality, not protocol: `Backend.MCP`
  (`MCPBackend`) → `Backend.LocalSubprocess` (`LocalSubprocessBackend`) and
  `Backend.Embedded` (`EmbeddedBackend`) → `Backend.LocalEmbedded`
  (`LocalEmbeddedBackend`). The first-order axis is local vs remote (remote is
  future). MCP is not a conformer identity; it survives only on the protocol client
  (`MCPClientKit` / `MCPClientAPI`), the one component that actually speaks it.
