import AppCore
import AppKit
import AppModels
import FrameworkBrowserFeature

/// A title-bar accessory that shows the live backend connection status as an SF Symbol,
/// kept in the window so it is always visible (a menu-bar status item gets silently dropped
/// on a crowded menu bar). Observes the framework view model's connection state and tints
/// the symbol: gray while connecting, green when connected (the backend-mode symbol:
/// `terminal` for MCP-over-stdio, `internaldrive` for the embedded corpus), red on error.
@MainActor
final class ConnectionStatusAccessory: NSTitlebarAccessoryViewController {
    private let frameworks: Feature.FrameworkBrowser.ViewModel
    private let mode: Model.BackendMode
    private let imageView = NSImageView()

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
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.symbolConfiguration = .init(pointSize: 14, weight: .semibold)
        let container = NSView()
        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            container.heightAnchor.constraint(equalToConstant: 28),
        ])
        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        track()
        render()
    }

    /// Re-render on every connection-state change, then re-arm the tracker.
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
        let tip: String
        switch frameworks.connectionState {
        case .connecting:
            symbol = "ellipsis.circle"
            color = .secondaryLabelColor
            tip = "Connecting to cupertino…"
        case .connected:
            symbol = mode.systemImage
            color = .systemGreen
            tip = "Connected: \(mode.label)"
        case .failed:
            symbol = "exclamationmark.triangle.fill"
            color = .systemRed
            tip = "Connection error: \(frameworks.errorMessage ?? "unknown")"
        }
        imageView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
        imageView.contentTintColor = color
        imageView.toolTip = tip
    }
}
