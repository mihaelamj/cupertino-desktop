import AppCore
import AppModels
import Observation
import PresentationBridge

#if canImport(AppKit)
    import AppKit

    public extension UI {
        /// The AppKit app shell: a two-column split view mirroring the SwiftUI
        /// `RootView`. The sidebar is the live framework list (`FrameworkSidebarViewController`
        /// over `Feature.FrameworkBrowser.ViewModel`); the detail renders the selected
        /// framework's document. Built entirely in code, no XIB (docs/rules/package-structure.md).
        ///
        /// Unlike SwiftUI's `NavigationSplitView`, AppKit does not hand you the
        /// sidebar-toggle toolbar button or column sizing for free, so this controller
        /// wires both explicitly: minimum thicknesses so both columns render, and
        /// an `NSToolbar` with a custom leading toggle button (`isNavigational`) that
        /// stays pinned by the title instead of sliding away when the sidebar collapses.
        @MainActor
        final class RootViewController: NSSplitViewController, NSToolbarDelegate {
            private let model: RootModel
            private let frameworks: any Presentation.FrameworkBrowserViewModelProtocol

            public init(model: RootModel, frameworks: any Presentation.FrameworkBrowserViewModelProtocol) {
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

                let sidebar = DatabaseListViewController(model: model, frameworks: frameworks)
                let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
                sidebarItem.minimumThickness = 200
                sidebarItem.maximumThickness = 360
                addSplitViewItem(sidebarItem)

                // The reader/detail column renders the selected framework's document.
                // Lower holding priority so it takes the slack when the window resizes.
                let detailItem = NSSplitViewItem(viewController: SelectionDetailViewController(frameworks: frameworks))
                detailItem.minimumThickness = 320
                detailItem.holdingPriority = .init(245)
                addSplitViewItem(detailItem)

                trackFrameworks()
                frameworks.onAppeared()
            }

            public func showFrameworks(for source: Model.Source) {
                frameworks.selectSource(source)
                let sidebar = FrameworkSidebarViewController(model: model, frameworks: frameworks)
                if let sidebarItem = splitViewItems.first {
                    sidebarItem.viewController.removeFromParent()
                    insertChild(sidebar, at: 0)
                    sidebarItem.viewController = sidebar
                }
            }

            public func showDatabases() {
                let databases = DatabaseListViewController(model: model, frameworks: frameworks)
                if let sidebarItem = splitViewItems.first {
                    sidebarItem.viewController.removeFromParent()
                    insertChild(databases, at: 0)
                    sidebarItem.viewController = databases
                }
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
                // Per NSToolbarItem.isNavigational: the system positions navigational
                // items at the leading edge of the window's title area (the same place as
                // Finder's back/forward buttons), so the toggle stays by the title instead
                // of tracking the sidebar and jumping on collapse.
                item.isNavigational = true
                item.target = self
                item.action = #selector(NSSplitViewController.toggleSidebar(_:))
                return item
            }

            private func trackFrameworks() {
                withObservationTracking {
                    _ = frameworks.frameworks
                } onChange: { [weak self] in
                    Task { @MainActor in
                        guard let self else { return }
                        if self.model.selectedFrameworkID == nil, let first = self.frameworks.frameworks.first {
                            self.model.selectedFrameworkID = first.id
                            self.frameworks.selectFramework(first.id)
                        }
                        self.trackFrameworks()
                    }
                }
            }
        }
    }
#endif
