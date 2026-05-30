import AppCore
import FrameworkBrowserFeature

#if canImport(AppKit)
    import AppKit

    public extension UI {
        /// The AppKit app shell: a three-column split view mirroring the SwiftUI
        /// `RootView`. The sidebar is the live framework list (`FrameworkSidebarViewController`
        /// over `Feature.FrameworkBrowser.ViewModel`); content and detail are still
        /// placeholders. Built entirely in code, no XIB (docs/rules/package-structure.md).
        ///
        /// Unlike SwiftUI's `NavigationSplitView`, AppKit does not hand you the
        /// sidebar-toggle toolbar button or column sizing for free, so this controller
        /// wires both explicitly: minimum thicknesses so all three columns render, and
        /// an `NSToolbar` with a custom leading toggle button (`isNavigational`) that
        /// stays pinned by the title instead of sliding away when the sidebar collapses.
        @MainActor
        final class RootViewController: NSSplitViewController, NSToolbarDelegate {
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
                let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
                sidebarItem.minimumThickness = 200
                sidebarItem.maximumThickness = 360
                addSplitViewItem(sidebarItem)

                // The document-list column (still a placeholder), a plain content item
                // with a floor so it cannot collapse away. (Not a content-list item: a
                // second collapsible region confuses the sidebar toggle.)
                let contentItem = NSSplitViewItem(
                    viewController: Self.placeholder("Select a framework", symbol: "books.vertical"),
                )
                contentItem.minimumThickness = 240
                addSplitViewItem(contentItem)

                // The reader/detail column. It mirrors the SwiftUI shell: the selected
                // framework id when one is chosen, the empty state otherwise. Lower
                // holding priority so it takes the slack when the window resizes.
                let detailItem = NSSplitViewItem(viewController: SelectionDetailViewController(model: model))
                detailItem.minimumThickness = 320
                detailItem.holdingPriority = .init(245)
                addSplitViewItem(detailItem)
            }

            override public func viewDidAppear() {
                super.viewDidAppear()
                guard let window = view.window, window.toolbar == nil else { return }
                // Start with the sidebar open (override any restored collapsed state).
                splitViewItems.first?.isCollapsed = false
                let toolbar = NSToolbar(identifier: "CupertinoMainToolbar")
                toolbar.delegate = self
                toolbar.displayMode = .iconOnly
                window.toolbar = toolbar
                window.toolbarStyle = .unified
            }

            // MARK: NSToolbarDelegate

            /// A single CUSTOM toggle button, and nothing else: no system `.toggleSidebar`
            /// (it is glued to the sidebar's toolbar region and slides to the trailing
            /// edge when the sidebar collapses), no `.sidebarTrackingSeparator`, no
            /// flexible space. As the only item it stays put at the leading edge in every
            /// state, and it still drives the split view's built-in `toggleSidebar(_:)`.
            private static let toggleItemID = NSToolbarItem.Identifier("cupertino.toggleSidebar")

            public func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
                [Self.toggleItemID]
            }

            public func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
                [Self.toggleItemID]
            }

            public func toolbar(
                _: NSToolbar,
                itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                willBeInsertedIntoToolbar _: Bool,
            ) -> NSToolbarItem? {
                guard itemIdentifier == Self.toggleItemID else { return nil }
                let item = NSToolbarItem(itemIdentifier: itemIdentifier)
                item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Toggle Sidebar")
                item.label = "Toggle Sidebar"
                item.toolTip = "Toggle Sidebar"
                item.isBordered = true
                item.isNavigational = true
                item.target = self
                item.action = #selector(NSSplitViewController.toggleSidebar(_:))
                return item
            }

            /// An empty-state placeholder column: a centered SF Symbol over a title,
            /// matching the SwiftUI shell's `ContentUnavailableView`.
            private static func placeholder(_ title: String, symbol: String) -> NSViewController {
                let controller = NSViewController()
                let container = NSView()

                let image = NSImageView()
                image.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
                image.symbolConfiguration = .init(pointSize: 36, weight: .regular)
                image.contentTintColor = .tertiaryLabelColor

                let label = NSTextField(labelWithString: title)
                label.font = .systemFont(ofSize: NSFont.systemFontSize + 4, weight: .semibold)
                label.textColor = .secondaryLabelColor

                let stack = NSStackView(views: [image, label])
                stack.orientation = .vertical
                stack.alignment = .centerX
                stack.spacing = 8
                stack.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(stack)
                NSLayoutConstraint.activate([
                    stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                ])
                controller.view = container
                return controller
            }
        }
    }
#endif
