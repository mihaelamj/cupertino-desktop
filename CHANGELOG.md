# Changelog

All notable changes to CupertinoDesktop are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- M0 skeleton: the `Packages/` SPM package with the layered target tree, both
  `Apps/` targets (SwiftUI and AppKit) generated from XcodeGen `project.yml`, and
  `Main.xcworkspace`. The UI ships as parallel native packages `ShellSwiftUI` /
  `ShellAppKit` (no NSHostingController or representable bridges) exposing a
  same-shaped `UI.RootExperience` over one shared, UI-framework-free
  `UI.RootModel`, so each app consumes its framework identically. Launches an
  empty split-view shell.
- Backend seam scaffold: a transport-agnostic, protocol-only package graph. The
  ONLY universal seam is `Backend.Documentation` (`BackendAPI`). MCP is confined
  to one conformer: `Backend.MCP` (`MCPBackend`) talks JSON-RPC via `MCPClient`
  (`MCPClientKit`, reusing cupertino's cross-platform `MCPCore` types) over a
  `Transport.Channel` (`TransportAPI`), with `Transport.Subprocess`
  (`SubprocessTransport`) spawning `cupertino serve`. `MacBackendImpl` is the
  composition root wiring those together; the future iOS embedded backend will
  be a separate direct-call conformer with no MCP. Real value types in
  `AppModels`. Method bodies are honest M1 placeholders (throw, never fake).
- `scripts/generate-xcodeproj.sh` to materialize the per-app Xcode projects from
  their `project.yml` manifests.
- Mobile (iOS) scaffold: the package now targets iOS 17 alongside macOS 15. New
  `CupertinoMobile` iOS app reuses the `ShellSwiftUI` shell and `AppCore` through
  the same `UI.RootExperience` seam as the macOS SwiftUI app. New
  `EmbeddedBackend` (`Backend.Embedded`, in-process cupertino, no MCP/subprocess)
  and `MobileBackendImpl` (`MobileBackend.live`) mirror the Mac path under the
  shared `Backend.Documentation` seam. Bodies are honest M1 placeholders.

### Changed

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
