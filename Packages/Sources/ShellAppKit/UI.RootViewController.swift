import AppCore

#if canImport(AppKit)
    import AppKit

    public extension UI {
        /// The AppKit app shell: an empty split view controller mirroring the SwiftUI
        /// `RootView`, bound to the shared `RootModel`. Milestone M0 placeholder, built
        /// entirely in code with no XIB (docs/rules/package-structure.md). Per-feature
        /// AppKit packages supply the column controllers later, injected at the app
        /// composition root.
        @MainActor
        final class RootViewController: NSSplitViewController {
            private let model: RootModel

            public init(model: RootModel) {
                self.model = model
                super.init(nibName: nil, bundle: nil)
            }

            @available(*, unavailable)
            public required init?(coder _: NSCoder) {
                fatalError("init(coder:) is unsupported; this app uses no XIBs.")
            }

            override public func viewDidLoad() {
                super.viewDidLoad()
                addSplitViewItem(
                    NSSplitViewItem(sidebarWithViewController: Self.placeholder("Frameworks")),
                )
                addSplitViewItem(
                    NSSplitViewItem(viewController: Self.placeholder("Select a framework")),
                )
                addSplitViewItem(
                    NSSplitViewItem(viewController: Self.placeholder("Select a document")),
                )
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
#endif
