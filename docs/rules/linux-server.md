# Linux-server Swift (server rules not applicable to this repo)

Cupertino Desktop ships **Linux and Windows Qt UIs** in the accepted design, but it
ships no Linux/Windows server: no Vapor/Hummingbird/NIO server, no Docker image, no
server-side SIGTERM/graceful-shutdown handling, no FluentSQLite/Postgres service. The MCP server
it talks to on macOS lives in the separate
[`cupertino`](https://github.com/mihaelamj/cupertino) repo; that repo, not this one,
owns the server-side operational rules.

So this rule is inert here and is **not** in the always-relevant set. The canonical
version (with the full HTTP / logging / database / signals / Docker guidance) lives
upstream at `mihaela-agents/Rules/public-swift/linux-server.md` for repos that do
ship a Linux server.

## The one part that does apply: subprocess lifecycle

This app spawns `cupertino serve` as a child process over stdio (see
[docs/DESIGN.md](../DESIGN.md) §7). Treat that subprocess as owned state:

- One long-lived `MCP.Client` owns the `Process`; connect lazily or at launch.
- Terminate the child on app termination; do not leak orphaned `cupertino serve`
  processes. Reconnect on demand if the child dies (surface it as a connection
  state, never a crash).
- A missing/incompatible `cupertino` binary or un-downloaded corpus is an expected
  first-run condition, not a fatal error: show an empty state with install guidance.

For the platform/UI seam (macOS, iPhone, iPad, Linux Qt, Windows Qt), see
[cross-platform.md](cross-platform.md).
