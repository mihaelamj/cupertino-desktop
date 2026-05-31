import AppCore
import AppModels
import Foundation
import FrameworkBrowserFeature
import MacBackendImpl
import SwiftUI
import UpcomingSwiftUI

/// The toolbar connection-status control: an SF Symbol tinted by the live connection state
/// (gray connecting, green connected, red error), showing the backend-mode symbol when
/// connected (`terminal` for MCP-over-stdio, `internaldrive` for the embedded corpus).
/// Tapping it opens a popover with real process info, the way you'd inspect it in the shell.
struct ConnectionStatusButton: View {
    let frameworks: Feature.FrameworkBrowser.ViewModel
    let mode: Model.BackendMode
    @State private var showInfo = false

    private var tint: Color {
        switch frameworks.connectionState {
        case .connecting: .secondary
        case .connected: .green
        case .failed: .red
        }
    }

    private var shortLabel: String {
        switch frameworks.connectionState {
        case .connecting: "Connecting"
        case .connected: mode == .mcpSubprocess ? "MCP" : "Embedded"
        case .failed: "Offline"
        }
    }

    var body: some View {
        chip
            .help("Connection: \(mode.label)")
            .popover(isPresented: $showInfo, arrowEdge: .bottom) {
                ConnectionInfoView(frameworks: frameworks, mode: mode)
            }
    }

    /// The chip adopts Liquid Glass via the `.glass` button style (a glass capsule that tracks
    /// the title bar's material), through the forward-compat shim so there is no inline
    /// `if #available` ceremony. See `UpcomingSwiftUI`, cross-platform.md Pattern 13, and #52.
    private var chip: some View {
        Button {
            showInfo.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: mode.systemImage)
                    .foregroundStyle(tint)
                Text(shortLabel)
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
        .upcoming.glassButtonStyle()
    }
}

/// The popover content: a monospaced diagnostics readout of the live connection, including
/// the actual `cupertino serve` process pulled from `pgrep` (refreshable).
private struct ConnectionInfoView: View {
    let frameworks: Feature.FrameworkBrowser.ViewModel
    let mode: Model.BackendMode
    @State private var processInfo = "…"

    private var statusText: String {
        switch frameworks.connectionState {
        case .connecting: "Connecting"
        case .connected: "Connected"
        case .failed: "Error"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: mode.systemImage)
                Text("Connection").font(.headline)
                Spacer()
                Button("Refresh") { processInfo = Self.liveProcess() }
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                row("Status", statusText)
                row("Backend", mode.label)
                row("Executable", CupertinoExecutable.resolve() ?? "not found")
                row("Command", mode == .mcpSubprocess ? "cupertino serve --no-reap" : "(in-process)")
                row("Frameworks", "\(frameworks.frameworks.count)")
                if let error = frameworks.errorMessage {
                    row("Error", error)
                }
            }
            Divider()
            Text("Process (pgrep -fl \"cupertino serve\")").font(.caption).foregroundStyle(.secondary)
            Text(processInfo)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(.body, design: .monospaced))
        .padding(16)
        .frame(width: 420)
        .onAppear { processInfo = Self.liveProcess() }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label).foregroundStyle(.secondary).frame(width: 92, alignment: .leading)
            Text(value).textSelection(.enabled)
        }
    }

    /// Run `pgrep -fl "cupertino serve"` and return its output, the live process info as the
    /// shell would show it. Empty result means no server is running.
    private static func liveProcess() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-fl", "cupertino serve"]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "pgrep failed: \(error.localizedDescription)"
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return output.isEmpty ? "(no cupertino serve process running)" : output
    }
}
