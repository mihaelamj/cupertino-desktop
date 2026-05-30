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
            private let progress = NSProgressIndicator()
            private let statusLabel = NSTextField(labelWithString: "")
            private let retryButton = NSButton()
            private let statusStack: NSStackView

            init(model: RootModel, frameworks: Feature.FrameworkBrowser.ViewModel) {
                self.model = model
                self.frameworks = frameworks
                statusStack = NSStackView(views: [progress, statusLabel, retryButton])
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
                tableView.dataSource = self
                tableView.delegate = self
                scrollView.documentView = tableView
                scrollView.hasVerticalScroller = true
                scrollView.drawsBackground = false
                scrollView.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(scrollView)

                progress.style = .spinning
                progress.controlSize = .small
                statusLabel.textColor = .secondaryLabelColor
                statusLabel.alignment = .center
                statusLabel.maximumNumberOfLines = 0
                retryButton.title = "Retry"
                retryButton.bezelStyle = .rounded
                retryButton.target = self
                retryButton.action = #selector(onRetryTapped)
                statusStack.orientation = .vertical
                statusStack.alignment = .centerX
                statusStack.spacing = 8
                statusStack.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(statusStack)

                NSLayoutConstraint.activate([
                    scrollView.topAnchor.constraint(equalTo: container.topAnchor),
                    scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    statusStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    statusStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    statusStack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 16),
                    statusStack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),
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

                progress.isHidden = !isLoading
                if isLoading { progress.startAnimation(nil) } else { progress.stopAnimation(nil) }
                statusLabel.isHidden = !isLoading && error == nil
                retryButton.isHidden = error == nil
                statusStack.isHidden = !isLoading && error == nil
                scrollView.isHidden = isLoading || error != nil

                if isLoading {
                    statusLabel.stringValue = "Loading frameworks"
                } else if let error {
                    statusLabel.stringValue = error
                }

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

            @objc private func onRetryTapped() {
                frameworks.onRetried()
            }

            // MARK: NSTableViewDataSource / Delegate

            func numberOfRows(in _: NSTableView) -> Int {
                frameworks.frameworks.count
            }

            func tableView(_: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
                let framework = frameworks.frameworks[row]
                let cell = NSTableCellView()

                let name = NSTextField(labelWithString: framework.name)
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
