import AppCore
import AppModels
import PresentationBridge

#if canImport(AppKit)
    import AppKit

    extension UI {
        /// The AppKit database list: renders the list of databases in an `NSTableView`.
        /// Selecting a database transitions the sidebar to show its frameworks list.
        @MainActor
        final class DatabaseListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
            private let model: RootModel
            private let frameworks: any Presentation.FrameworkBrowserViewModelProtocol
            private let tableView = NSTableView()
            private let scrollView = NSScrollView()

            private var sources: [Model.Source] {
                frameworks.sources
            }

            init(model: RootModel, frameworks: any Presentation.FrameworkBrowserViewModelProtocol) {
                self.model = model
                self.frameworks = frameworks
                super.init(nibName: nil, bundle: nil)
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError("init(coder:) is unsupported")
            }

            override func viewDidLoad() {
                super.viewDidLoad()
                trackState()
            }

            private func trackState() {
                withObservationTracking {
                    _ = frameworks.sources
                } onChange: { [weak self] in
                    Task { @MainActor in
                        guard let self else { return }
                        self.tableView.reloadData()
                        self.trackState()
                    }
                }
            }

            override func loadView() {
                let container = NSView()
                let column = NSTableColumn(identifier: .init("database"))
                column.resizingMask = .autoresizingMask
                tableView.addTableColumn(column)
                tableView.headerView = nil
                tableView.style = .sourceList
                tableView.rowHeight = 40
                tableView.dataSource = self
                tableView.delegate = self
                tableView.setAccessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.sidebar)
                scrollView.documentView = tableView
                scrollView.hasVerticalScroller = true
                scrollView.drawsBackground = false
                scrollView.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(scrollView)

                NSLayoutConstraint.activate([
                    scrollView.topAnchor.constraint(equalTo: container.topAnchor),
                    scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                ])
                view = container
            }

            // MARK: NSTableViewDataSource / Delegate

            func numberOfRows(in _: NSTableView) -> Int {
                sources.count
            }

            func tableView(_: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
                let source = sources[row]
                let cell = NSTableCellView()

                let name = NSTextField(labelWithString: displayName(for: source))
                name.font = .systemFont(ofSize: NSFont.systemFontSize + 3, weight: .bold)
                name.setAccessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.sourceRow(source.rawValue))

                let icon = NSImageView(image: NSImage(systemSymbolName: iconName(for: source), accessibilityDescription: nil) ?? NSImage())

                icon.translatesAutoresizingMaskIntoConstraints = false
                name.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(icon)
                cell.addSubview(name)

                NSLayoutConstraint.activate([
                    icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                    icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    icon.widthAnchor.constraint(equalToConstant: 20),
                    icon.heightAnchor.constraint(equalToConstant: 20),

                    name.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
                    name.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                    name.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                ])
                return cell
            }

            func tableViewSelectionDidChange(_: Notification) {
                let row = tableView.selectedRow
                guard row >= 0, row < sources.count else { return }
                let source = sources[row]
                (parent as? RootViewController)?.showFrameworks(for: source)
            }

            private func displayName(for source: Model.Source) -> String {
                source.displayName
            }

            private func iconName(for source: Model.Source) -> String {
                source.iconName
            }
        }
    }
#endif
