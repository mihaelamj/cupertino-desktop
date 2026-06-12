import AppCore
import AppModels
import PresentationBridge

#if canImport(AppKit)
    import AppKit

    extension UI {
        /// The AppKit sidebar: renders `Feature.FrameworkBrowser.ViewModel` as an
        /// `NSTableView`. It is the one-to-one counterpart of the SwiftUI sidebar in
        /// `RootView`, the same view model, the same three states (loading, error with
        /// retry, list), differing only in view code. State changes are picked up with
        /// `withObservationTracking`, the AppKit equivalent of SwiftUI's automatic
        /// `@Observable` tracking.
        @MainActor
        final class FrameworkSidebarViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
            private let model: RootModel
            private let frameworks: any Presentation.FrameworkBrowserViewModelProtocol

            private let tableView = NSTableView()
            private let scrollView = NSScrollView()
            /// AppKit ships no `ContentUnavailableView`; `UI.ContentUnavailableView` is the
            /// native replica, used for the loading and error states (matching SwiftUI/UIKit).
            private let unavailable = UI.ContentUnavailableView()

            private let titleLabel = NSTextField(labelWithString: "")
            private let backButton = NSButton()
            private let searchField = NSSearchField()
            private let sortButton = NSButton()

            init(model: RootModel, frameworks: any Presentation.FrameworkBrowserViewModelProtocol) {
                self.model = model
                self.frameworks = frameworks
                super.init(nibName: nil, bundle: nil)
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError("init(coder:) is unsupported; this app uses no XIBs.")
            }

            override func loadView() {
                let container = NSView()

                let column = NSTableColumn(identifier: .init("framework"))
                column.resizingMask = .autoresizingMask
                tableView.addTableColumn(column)
                tableView.headerView = nil
                tableView.style = .sourceList
                tableView.rowHeight = 30
                tableView.dataSource = self
                tableView.delegate = self
                tableView.setAccessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.sidebar)
                scrollView.documentView = tableView
                scrollView.hasVerticalScroller = true
                scrollView.drawsBackground = false
                scrollView.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(scrollView)

                unavailable.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(unavailable)

                titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize + 3, weight: .bold)
                titleLabel.lineBreakMode = .byTruncatingTail
                titleLabel.translatesAutoresizingMaskIntoConstraints = false

                backButton.bezelStyle = .texturedRounded
                backButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")
                backButton.target = self
                backButton.action = #selector(goBack)
                backButton.translatesAutoresizingMaskIntoConstraints = false

                let titleStack = NSStackView(views: [backButton, titleLabel])
                titleStack.orientation = .horizontal
                titleStack.alignment = .centerY
                titleStack.spacing = 8
                titleStack.translatesAutoresizingMaskIntoConstraints = false

                searchField.placeholderString = "Search Frameworks"
                searchField.delegate = self
                searchField.setAccessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.searchField)
                searchField.translatesAutoresizingMaskIntoConstraints = false

                sortButton.bezelStyle = .texturedRounded
                sortButton.image = NSImage(systemSymbolName: "arrow.up.arrow.down.circle", accessibilityDescription: "Sort")
                sortButton.target = self
                sortButton.action = #selector(showSortMenu)
                sortButton.setAccessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.sortButton)
                sortButton.translatesAutoresizingMaskIntoConstraints = false

                let searchStack = NSStackView(views: [searchField, sortButton])
                searchStack.orientation = .horizontal
                searchStack.alignment = .centerY
                searchStack.spacing = 8
                searchStack.translatesAutoresizingMaskIntoConstraints = false

                let topStack = NSStackView(views: [titleStack, searchStack])
                topStack.orientation = .vertical
                topStack.alignment = .leading
                topStack.spacing = 8
                topStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
                topStack.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(topStack)

                NSLayoutConstraint.activate([
                    titleStack.leadingAnchor.constraint(equalTo: topStack.leadingAnchor),
                    titleStack.trailingAnchor.constraint(equalTo: topStack.trailingAnchor),
                    searchStack.leadingAnchor.constraint(equalTo: topStack.leadingAnchor),
                    searchStack.trailingAnchor.constraint(equalTo: topStack.trailingAnchor),
                ])

                NSLayoutConstraint.activate([
                    topStack.topAnchor.constraint(equalTo: container.topAnchor),
                    topStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    topStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),

                    scrollView.topAnchor.constraint(equalTo: topStack.bottomAnchor),
                    scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),

                    unavailable.topAnchor.constraint(equalTo: topStack.bottomAnchor),
                    unavailable.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    unavailable.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    unavailable.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                ])
                view = container
            }

            override func viewDidLoad() {
                super.viewDidLoad()
                trackState()
                render()
                frameworks.onAppeared()
            }

            /// Re-render on every view-model state change, then re-arm the tracker
            /// (a single `withObservationTracking` fires once).
            private func trackState() {
                withObservationTracking {
                    _ = frameworks.frameworks
                    _ = frameworks.state
                } onChange: { [weak self] in
                    Task { @MainActor in
                        guard let self else { return }
                        self.render()
                        self.trackState()
                    }
                }
            }

            private func render() {
                let isLoading = frameworks.isLoading
                let error = frameworks.errorMessage
                let itemTerm = frameworks.selectedSource?.itemTerm ?? "Frameworks"
                let lowerTerm = itemTerm.lowercased()

                if let source = frameworks.selectedSource {
                    titleLabel.stringValue = source.displayName
                    searchField.placeholderString = "Search \(source.itemTerm)"
                }

                if isLoading {
                    unavailable.showLoading(title: "Loading \(lowerTerm)")
                } else if let error {
                    unavailable.show(
                        systemImage: "exclamationmark.triangle",
                        title: "Could not load \(lowerTerm)",
                        message: error,
                        actionTitle: "Retry",
                    ) { [weak self] in self?.frameworks.onRetried() }
                }
                let showUnavailable = isLoading || error != nil
                unavailable.isHidden = !showUnavailable
                scrollView.isHidden = showUnavailable

                tableView.reloadData()
                // Pre-select the first framework once the list loads so the detail shows a
                // document instead of the empty state (selecting the row drives the load).
                if model.selectedFrameworkID == nil, let first = frameworks.frameworks.first {
                    model.selectedFrameworkID = first.id
                }
                syncSelectionFromModel()
            }

            @objc private func goBack() {
                (parent as? RootViewController)?.showDatabases()
            }

            @objc private func showSortMenu() {
                let menu = NSMenu(title: "Sort By")
                let currentOrder = frameworks.sortOrder
                let nameItem = NSMenuItem(title: "Name", action: #selector(sortByName), keyEquivalent: "")
                nameItem.target = self
                nameItem.state = currentOrder == .name ? .on : .off
                nameItem.setAccessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.sortByNameOption)
                let countItem = NSMenuItem(title: "Count", action: #selector(sortByCount), keyEquivalent: "")
                countItem.target = self
                countItem.state = currentOrder == .count ? .on : .off
                countItem.setAccessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.sortByCountOption)
                menu.addItem(nameItem)
                menu.addItem(countItem)

                NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent ?? NSEvent(), for: sortButton)
            }

            @objc private func sortByName() {
                frameworks.sortOrder = .name
            }

            @objc private func sortByCount() {
                frameworks.sortOrder = .count
            }

            // MARK: - NSSearchFieldDelegate

            func controlTextDidChange(_ obj: Notification) {
                guard let field = obj.object as? NSSearchField else { return }
                frameworks.searchQuery = field.stringValue
            }

            private func syncSelectionFromModel() {
                guard let id = model.selectedFrameworkID,
                      let row = frameworks.frameworks.firstIndex(where: { $0.id == id })
                else { return }
                if tableView.selectedRow != row {
                    tableView.selectRowIndexes([row], byExtendingSelection: false)
                }
            }

            // MARK: NSTableViewDataSource / Delegate

            func numberOfRows(in _: NSTableView) -> Int {
                frameworks.frameworks.count
            }

            func tableView(_: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
                let framework = frameworks.frameworks[row]
                let cell = NSTableCellView()

                let name = NSTextField(labelWithString: framework.displayName)
                name.font = .systemFont(ofSize: NSFont.systemFontSize + 3)
                // The identifier goes on the visible label, not the cell view: an
                // `NSTableCellView`'s `accessibilityIdentifier` does not surface to XCUITest
                // (the synthesized AX cell carries no identifier), but the label does.
                name.setAccessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.row(framework.id))
                let count = NSTextField(labelWithString: framework.documentCount.formatted())
                count.textColor = .secondaryLabelColor
                count.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
                name.translatesAutoresizingMaskIntoConstraints = false
                count.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(name)
                cell.addSubview(count)

                NSLayoutConstraint.activate([
                    name.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    name.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    count.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                    count.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    count.leadingAnchor.constraint(greaterThanOrEqualTo: name.trailingAnchor, constant: 8),
                ])
                return cell
            }

            func tableViewSelectionDidChange(_: Notification) {
                let row = tableView.selectedRow
                guard row >= 0, row < frameworks.frameworks.count else { return }
                let id = frameworks.frameworks[row].id
                model.selectedFrameworkID = id
                frameworks.selectFramework(id)
            }
        }
    }
#endif
