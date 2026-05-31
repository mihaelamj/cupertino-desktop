import AppCore
import AppKit
import AppModels
import FrameworkBrowserFeature
import MacBackendImpl

/// A title-bar accessory showing the live backend connection status as a tappable chip
/// (SF Symbol tinted by state + short label), kept in the window so it is always visible
/// (a menu-bar status item gets silently dropped on a crowded menu bar). Mirrors the SwiftUI
/// connection chip: gray connecting, green connected (mode symbol `terminal` for MCP-over-
/// stdio, `internaldrive` for the embedded corpus), red offline. Clicking opens a popover
/// with real process info (`pgrep` of `cupertino serve`, executable, command, framework count).
@MainActor
final class ConnectionStatusAccessory: NSTitlebarAccessoryViewController {
    private let frameworks: Feature.FrameworkBrowser.ViewModel
    private let mode: Model.BackendMode
    private let button = NSButton()
    private var popover: NSPopover?

    init(frameworks: Feature.FrameworkBrowser.ViewModel, mode: Model.BackendMode) {
        self.frameworks = frameworks
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
        layoutAttribute = .right
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is unsupported; this app uses no XIBs.")
    }

    override func loadView() {
        button.isBordered = false
        button.imagePosition = .imageLeading
        button.font = .systemFont(ofSize: NSFont.systemFontSize)
        button.target = self
        button.action = #selector(togglePopover)
        button.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 96, height: 28))
        container.heightAnchor.constraint(equalToConstant: 28).isActive = true

        // On macOS 26 the chip rides in a Liquid Glass capsule (NSGlassEffectView), mirroring
        // the SwiftUI `.glass` button style; on macOS 15 to 25, where the API does not exist, it
        // falls back to the bare borderless button. See cupertino-desktop #52.
        if #available(macOS 26, *) {
            // The button is padded inside an inner view so the glass material has breathing room
            // around the label rather than clipping it (NSGlassEffectView fills its contentView).
            let padded = NSView()
            padded.addSubview(button)
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: padded.topAnchor),
                button.bottomAnchor.constraint(equalTo: padded.bottomAnchor),
                button.leadingAnchor.constraint(equalTo: padded.leadingAnchor, constant: 10),
                button.trailingAnchor.constraint(equalTo: padded.trailingAnchor, constant: -10),
            ])
            let glass = NSGlassEffectView()
            glass.translatesAutoresizingMaskIntoConstraints = false
            glass.cornerRadius = 14
            glass.contentView = padded
            container.addSubview(glass)
            NSLayoutConstraint.activate([
                glass.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                glass.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                glass.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
                glass.heightAnchor.constraint(equalToConstant: 26),
            ])
        } else {
            container.addSubview(button)
            NSLayoutConstraint.activate([
                button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
                button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            ])
        }
        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        track()
        render()
    }

    private func track() {
        withObservationTracking {
            _ = frameworks.connectionState
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.render()
                self.track()
            }
        }
    }

    private func render() {
        let symbol: String
        let color: NSColor
        let label: String
        switch frameworks.connectionState {
        case .connecting:
            symbol = "ellipsis.circle"
            color = .secondaryLabelColor
            label = "Connecting"
        case .connected:
            symbol = mode.systemImage
            color = .systemGreen
            label = mode == .mcpSubprocess ? "MCP" : "Embedded"
        case .failed:
            symbol = "exclamationmark.triangle.fill"
            color = .systemRed
            label = "Offline"
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        button.image = image?.withSymbolConfiguration(.init(paletteColors: [color]))
        button.attributedTitle = NSAttributedString(
            string: " \(label)",
            attributes: [.foregroundColor: NSColor.secondaryLabelColor, .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)],
        )
        button.toolTip = "Connection: \(mode.label)"
    }

    @objc private func togglePopover() {
        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = ConnectionInfoViewController(frameworks: frameworks, mode: mode)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        self.popover = popover
    }
}

/// The popover body: a monospaced diagnostics readout, including the live `cupertino serve`
/// process from `pgrep`, the way you'd inspect it in the shell.
@MainActor
private final class ConnectionInfoViewController: NSViewController {
    private let frameworks: Feature.FrameworkBrowser.ViewModel
    private let mode: Model.BackendMode

    init(frameworks: Feature.FrameworkBrowser.ViewModel, mode: Model.BackendMode) {
        self.frameworks = frameworks
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is unsupported; this app uses no XIBs.")
    }

    override func loadView() {
        let status = switch frameworks.connectionState {
        case .connecting: "Connecting"
        case .connected: "Connected"
        case .failed: "Error"
        }
        let lines = [
            "Status:      \(status)",
            "Backend:     \(mode.label)",
            "Executable:  \(CupertinoExecutable.resolve() ?? "not found")",
            "Command:     \(mode == .mcpSubprocess ? "cupertino serve --no-reap" : "(in-process)")",
            "Frameworks:  \(frameworks.frameworks.count)",
            frameworks.errorMessage.map { "Error:       \($0)" },
            "",
            "Process (pgrep -fl \"cupertino serve\"):",
            Self.liveProcess(),
        ].compactMap(\.self)

        let field = NSTextField(wrappingLabelWithString: lines.joined(separator: "\n"))
        field.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        field.isSelectable = true
        field.preferredMaxLayoutWidth = 420
        field.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(field)
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            field.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
            field.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            field.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            // A fixed width so the wrapping label computes its height and the popover sizes
            // to real content (without it the popover collapsed to a blank vertical pill).
            field.widthAnchor.constraint(equalToConstant: 420),
        ])
        container.frame = NSRect(x: 0, y: 0, width: 452, height: 240)
        view = container
    }

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
