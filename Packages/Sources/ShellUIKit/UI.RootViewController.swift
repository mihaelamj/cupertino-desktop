import AppCore
import FrameworkBrowserFeature

#if canImport(UIKit)
    import UIKit

    public extension UI {
        /// The UIKit app shell: a three-column `UISplitViewController` mirroring the
        /// SwiftUI `RootView` and the AppKit `RootViewController`. The primary column is
        /// the live framework list (`FrameworkSidebarViewController` over
        /// `Feature.FrameworkBrowser.ViewModel`); the supplementary and secondary
        /// columns are still placeholders. Built entirely in code, no storyboard.
        ///
        /// `UISplitViewController` is what gives the device adaptivity, and comparing it
        /// against SwiftUI's `NavigationSplitView` is the point of building both: on iPad
        /// regular width it lays the three columns side by side; on iPhone compact width
        /// it collapses into one navigation stack. The delegate pins that collapse to the
        /// primary column, so an iPhone opens on the framework list (not an empty
        /// detail), and selecting a row pushes the detail with `show(.secondary)`.
        @MainActor
        final class RootViewController: UISplitViewController, UISplitViewControllerDelegate {
            private let model: RootModel
            private let frameworks: Feature.FrameworkBrowser.ViewModel

            public init(model: RootModel, frameworks: Feature.FrameworkBrowser.ViewModel) {
                self.model = model
                self.frameworks = frameworks
                super.init(style: .tripleColumn)
            }

            @available(*, unavailable)
            public required init?(coder _: NSCoder) {
                fatalError("init(coder:) is unsupported; this app uses no storyboards.")
            }

            override public func viewDidLoad() {
                super.viewDidLoad()
                delegate = self
                preferredDisplayMode = .twoBesideSecondary
                preferredSplitBehavior = .tile

                // Column-style `UISplitViewController` embeds each column in its own
                // navigation controller, so the columns are set as plain controllers:
                // wrapping them again nests a second navigation bar (a stray back button).
                let sidebar = FrameworkSidebarViewController(model: model, frameworks: frameworks)
                sidebar.title = "Cupertino"
                setViewController(sidebar, for: .primary)
                setViewController(Self.placeholder("Select a framework", symbol: "books.vertical"), for: .supplementary)
                setViewController(SelectionDetailViewController(model: model), for: .secondary)
            }

            // MARK: UISplitViewControllerDelegate

            /// On iPhone (compact width) collapse to the sidebar so the framework list is
            /// the first screen, matching the SwiftUI shell's compact behaviour.
            public func splitViewController(
                _: UISplitViewController,
                topColumnForCollapsingToProposedTopColumn _: UISplitViewController.Column,
            ) -> UISplitViewController.Column {
                .primary
            }

            /// A centered SF Symbol over a title, matching the SwiftUI shell's
            /// `ContentUnavailableView` and the AppKit placeholder column.
            private static func placeholder(_ title: String, symbol: String) -> UIViewController {
                let controller = UIViewController()
                controller.view.backgroundColor = .systemBackground

                let image = UIImageView(image: UIImage(systemName: symbol))
                image.tintColor = .tertiaryLabel
                image.contentMode = .scaleAspectFit
                image.preferredSymbolConfiguration = .init(pointSize: 36, weight: .regular)

                let label = UILabel()
                label.text = title
                label.font = .preferredFont(forTextStyle: .headline)
                label.textColor = .secondaryLabel

                let stack = UIStackView(arrangedSubviews: [image, label])
                stack.axis = .vertical
                stack.alignment = .center
                stack.spacing = 8
                stack.translatesAutoresizingMaskIntoConstraints = false
                controller.view.addSubview(stack)
                NSLayoutConstraint.activate([
                    stack.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
                    stack.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor),
                ])
                return controller
            }
        }
    }
#endif
