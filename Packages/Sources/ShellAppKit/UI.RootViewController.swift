import AppCore
import FrameworkBrowserFeature

#if canImport(AppKit)
    import AppKit

    public extension UI {
        /// The AppKit app shell: a three-column split view mirroring the SwiftUI
        /// `RootView`. The sidebar is the live framework list (`FrameworkSidebarViewController`
        /// over `Feature.FrameworkBrowser.ViewModel`); content and detail are still
        /// placeholders. Built entirely in code, no XIB (docs/rules/package-structure.md).
        @MainActor
        final class RootViewController: NSSplitViewController {
            private let model: RootModel
            private let frameworks: Feature.FrameworkBrowser.ViewModel

            public init(model: RootModel, frameworks: Feature.FrameworkBrowser.ViewModel) {
                self.model = model
                self.frameworks = frameworks
                super.init(nibName: nil, bundle: nil)
            }

            @available(*, unavailable)
            public required init?(coder _: NSCoder) {
                fatalError("init(coder:) is unsupported; this app uses no XIBs.")
            }

            override public func viewDidLoad() {
                super.viewDidLoad()
                let sidebar = FrameworkSidebarViewController(model: model, frameworks: frameworks)
                addSplitViewItem(NSSplitViewItem(sidebarWithViewController: sidebar))
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
