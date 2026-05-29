import AppKit
import DesktopModels
import DesktopUI
import SearchAppKit
import SearchFeature

public extension CupertinoDesktop.UI {
    /// The AppKit combined flow: assembles the native screens into a split-view
    /// root behind the shared `Flow` seam. Milestone M0 wires the search screen;
    /// the remaining columns fill in as their features land.
    @MainActor
    struct AppKitFlow: CupertinoDesktop.UI.Flow {
        public init() {}

        public func makeRootController() -> CupertinoDesktop.UI.ViewController {
            let split = NSSplitViewController()

            let sidebar = Self.placeholder("Frameworks")
            let search = CupertinoDesktop.UI.Search.AppKitScreen()
            let detail = search.makeController(model: CupertinoDesktop.Feature.Search.Model())

            split.addSplitViewItem(NSSplitViewItem(sidebarWithViewController: sidebar))
            split.addSplitViewItem(NSSplitViewItem(viewController: detail))
            return split
        }

        private static func placeholder(_ title: String) -> NSViewController {
            let controller = NSViewController()
            let container = NSView()
            let label = NSTextField(labelWithString: title)
            label.textColor = .secondaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
            controller.view = container
            return controller
        }
    }
}
