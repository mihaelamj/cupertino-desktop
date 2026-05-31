import AppCore
import AppModels
import FrameworkBrowserFeature

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
        final class FrameworkSidebarViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
            private let model: RootModel
            private let frameworks: Feature.FrameworkBrowser.ViewModel

            private let tableView = NSTableView()
            private let scrollView = NSScrollView()
            /// AppKit ships no `ContentUnavailableView`; `UI.ContentUnavailableView` is the
            /// native replica, used for the loading and error states (matching SwiftUI/UIKit).
            private let unavailable = UI.ContentUnavailableView()

            init(model: RootModel, frameworks: Feature.FrameworkBrowser.ViewModel) {
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

                NSLayoutConstraint.activate([
                    scrollView.topAnchor.constraint(equalTo: container.topAnchor),
                    scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    unavailable.topAnchor.constraint(equalTo: container.topAnchor),
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

                if isLoading {
                    unavailable.showLoading(title: "Loading frameworks")
                } else if let error {
                    unavailable.show(
                        systemImage: "exclamationmark.triangle",
                        title: "Could not load frameworks",
                        message: error,
                        actionTitle: "Retry",
                    ) { [weak self] in self?.frameworks.onRetried() }
                }
                let showUnavailable = isLoading || error != nil
                unavailable.isHidden = !showUnavailable
                scrollView.isHidden = showUnavailable

                tableView.reloadData()
                syncSelectionFromModel()
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
