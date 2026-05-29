import AppKit
import DesktopModels
import DesktopUI
import SearchFeature

public extension CupertinoDesktop.UI.Search {
    /// The native AppKit search screen. Milestone M0 placeholder; binds to the
    /// shared `Feature.Search.Model` and grows a real query UI in M3.
    @MainActor
    final class AppKitController: NSViewController {
        private let model: CupertinoDesktop.Feature.Search.Model

        public init(model: CupertinoDesktop.Feature.Search.Model) {
            self.model = model
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        public required init?(coder _: NSCoder) {
            fatalError("init(coder:) is unsupported; this app uses no XIBs.")
        }

        override public func loadView() {
            let container = NSView()
            let label = NSTextField(labelWithString: "Search (AppKit)")
            label.textColor = .secondaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
            view = container
        }
    }
}
