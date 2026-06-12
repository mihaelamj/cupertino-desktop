import AppCore
import AppModels
import PresentationBridge

#if canImport(UIKit)
    import UIKit

    extension UI {
        /// The UIKit sidebar: renders `Feature.FrameworkBrowser.ViewModel` as a
        /// `UITableView`. One-to-one counterpart of the SwiftUI and AppKit sidebars, the
        /// same view model and the same three states (loading, error with retry, list),
        /// differing only in view code. State changes are picked up with
        /// `withObservationTracking`, the UIKit equivalent of SwiftUI's automatic
        /// `@Observable` tracking.
        @MainActor
        final class FrameworkSidebarViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating, UISearchBarDelegate {
            private let model: RootModel
            private let frameworks: any Presentation.FrameworkBrowserViewModelProtocol

            private let tableView = UITableView(frame: .zero, style: .insetGrouped)
            private static let cellID = "framework"
            private let searchController = UISearchController(searchResultsController: nil)

            init(model: RootModel, frameworks: any Presentation.FrameworkBrowserViewModelProtocol) {
                self.model = model
                self.frameworks = frameworks
                super.init(nibName: nil, bundle: nil)
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError("init(coder:) is unsupported; this app uses no storyboards.")
            }

            override func viewDidLoad() {
                super.viewDidLoad()
                view.backgroundColor = .systemBackground

                tableView.dataSource = self
                tableView.delegate = self
                tableView.accessibilityIdentifier = UI.AccessibilityID.FrameworkBrowser.sidebar
                tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellID)
                tableView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(tableView)

                NSLayoutConstraint.activate([
                    tableView.topAnchor.constraint(equalTo: view.topAnchor),
                    tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                    tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                ])

                searchController.searchResultsUpdater = self
                searchController.searchBar.delegate = self
                searchController.obscuresBackgroundDuringPresentation = false
                searchController.hidesNavigationBarDuringPresentation = false
                searchController.searchBar.placeholder = "Search Frameworks"
                searchController.searchBar.accessibilityIdentifier = UI.AccessibilityID.FrameworkBrowser.searchField
                navigationItem.searchController = searchController
                navigationItem.hidesSearchBarWhenScrolling = false
                definesPresentationContext = true

                trackState()
                render()
                frameworks.onAppeared()
            }

            /// Compact width (iPhone) uses push navigation, so deselect the row on return
            /// ("Handling row selection in a table view"). Regular width (iPad) keeps the
            /// selection highlighted (Split Views HIG); see `syncSelectionFromModel`.
            override func viewWillAppear(_ animated: Bool) {
                super.viewWillAppear(animated)
                guard splitViewController?.isCollapsed == true, let selected = tableView.indexPathForSelectedRow else { return }
                tableView.deselectRow(at: selected, animated: animated)
            }

            override func viewDidDisappear(_ animated: Bool) {
                super.viewDidDisappear(animated)
                if isMovingFromParent || isBeingDismissed {
                    if splitViewController?.isCollapsed == true {
                        frameworks.selectSource(nil)
                    }
                }
            }

            override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
                super.traitCollectionDidChange(previousTraitCollection)
                if traitCollection.horizontalSizeClass == .regular {
                    syncSelectionFromModel()
                } else {
                    if let selected = tableView.indexPathForSelectedRow {
                        tableView.deselectRow(at: selected, animated: false)
                    }
                }
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
                    title = source.displayName
                    searchController.searchBar.placeholder = "Search \(source.itemTerm)"
                }

                // Loading and error are shown as a system content-unavailable view (the UIKit
                // counterpart of SwiftUI's `ContentUnavailableView`), so all three UIs present
                // the same empty/error state; the table is shown only once frameworks load.
                if isLoading {
                    var loadingConfig = UIContentUnavailableConfiguration.loading()
                    loadingConfig.text = "Loading \(lowerTerm)"
                    contentUnavailableConfiguration = loadingConfig
                } else if let error {
                    contentUnavailableConfiguration = Self.errorConfiguration(term: lowerTerm, message: error) { [weak self] in
                        self?.frameworks.onRetried()
                    }
                } else {
                    contentUnavailableConfiguration = nil
                }
                tableView.isHidden = isLoading || error != nil

                updateSortButton()
                tableView.reloadData()
                syncSelectionFromModel()
            }

            private func updateSortButton() {
                let currentOrder = frameworks.sortOrder
                let nameAction = UIAction(title: "Name", image: UIImage(systemName: "textformat"), state: currentOrder == .name ? .on : .off) { [weak self] _ in
                    self?.frameworks.sortOrder = .name
                }
                let countAction = UIAction(title: "Count", image: UIImage(systemName: "number"), state: currentOrder == .count ? .on : .off) { [weak self] _ in
                    self?.frameworks.sortOrder = .count
                }
                let menu = UIMenu(title: "Sort By", children: [nameAction, countAction])
                let sortItem = UIBarButtonItem(title: "Sort", image: UIImage(systemName: "arrow.up.arrow.down.circle"), menu: menu)
                sortItem.accessibilityIdentifier = UI.AccessibilityID.FrameworkBrowser.sortButton
                navigationItem.rightBarButtonItem = sortItem
            }

            func updateSearchResults(for searchController: UISearchController) {
                frameworks.searchQuery = searchController.searchBar.text ?? ""
            }

            func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
                searchBar.resignFirstResponder()
            }

            /// A content-unavailable configuration for the load-failure state: an icon, the
            /// context-sensitive error title, the backend's message, and a Retry button.
            private static func errorConfiguration(term: String, message: String, retry: @escaping () -> Void) -> UIContentUnavailableConfiguration {
                var configuration = UIContentUnavailableConfiguration.empty()
                configuration.image = UIImage(systemName: "exclamationmark.triangle")
                configuration.text = "Could not load \(term)"
                configuration.secondaryText = message
                var button = UIButton.Configuration.bordered()
                button.title = "Retry"
                configuration.button = button
                configuration.buttonProperties.primaryAction = UIAction { _ in retry() }
                return configuration
            }

            private func syncSelectionFromModel() {
                guard splitViewController?.isCollapsed != true else { return } // iPad only; iPhone deselects on return
                guard let id = model.selectedFrameworkID,
                      let row = frameworks.frameworks.firstIndex(where: { $0.id == id })
                else { return }
                let indexPath = IndexPath(row: row, section: 0)
                if tableView.indexPathForSelectedRow != indexPath {
                    tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                }
            }

            // MARK: UITableViewDataSource / Delegate

            func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
                frameworks.frameworks.count
            }

            func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
                let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellID, for: indexPath)
                guard indexPath.row < frameworks.frameworks.count else {
                    return cell
                }
                let framework = frameworks.frameworks[indexPath.row]
                cell.accessibilityIdentifier = UI.AccessibilityID.FrameworkBrowser.row(framework.id)

                var content = cell.defaultContentConfiguration()
                content.text = framework.displayName
                content.textProperties.font = .preferredFont(forTextStyle: .title3)
                cell.contentConfiguration = content

                let count = UILabel()
                count.text = framework.documentCount.formatted()
                count.textColor = .secondaryLabel
                count.font = .monospacedDigitSystemFont(ofSize: UIFont.labelFontSize, weight: .regular)
                count.sizeToFit()
                cell.accessoryView = count
                return cell
            }

            func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
                guard indexPath.row < frameworks.frameworks.count else { return }
                let id = frameworks.frameworks[indexPath.row].id
                model.selectedFrameworkID = id
                frameworks.selectFramework(id)
                if let split = splitViewController {
                    split.show(.secondary)
                } else {
                    navigationController?.pushViewController(
                        SelectionDetailViewController(model: model, frameworks: frameworks),
                        animated: true,
                    )
                }
            }
        }

        @MainActor
        final class DatabaseListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
            private let model: RootModel
            private let frameworks: any Presentation.FrameworkBrowserViewModelProtocol
            private let tableView = UITableView(frame: .zero, style: .insetGrouped)
            private static let cellID = "databaseCell"

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
                fatalError("init(coder:) is unsupported; this app uses no storyboards.")
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

            override func viewDidLoad() {
                super.viewDidLoad()
                trackState()
                title = "Databases"
                view.backgroundColor = .systemBackground

                tableView.dataSource = self
                tableView.delegate = self
                tableView.accessibilityIdentifier = UI.AccessibilityID.FrameworkBrowser.sidebar
                tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellID)
                tableView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(tableView)

                NSLayoutConstraint.activate([
                    tableView.topAnchor.constraint(equalTo: view.topAnchor),
                    tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                    tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                ])
                frameworks.onAppeared()
            }

            override func viewWillAppear(_ animated: Bool) {
                super.viewWillAppear(animated)
                if let selected = tableView.indexPathForSelectedRow {
                    tableView.deselectRow(at: selected, animated: animated)
                }
            }

            private func iconName(for source: Model.Source) -> String {
                source.iconName
            }

            // MARK: - UITableViewDataSource / Delegate

            func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
                sources.count
            }

            func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
                let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellID, for: indexPath)
                let source = sources[indexPath.row]
                cell.accessibilityIdentifier = UI.AccessibilityID.FrameworkBrowser.sourceRow(source.rawValue)

                var content = cell.defaultContentConfiguration()
                content.text = source.displayName
                content.textProperties.font = .preferredFont(forTextStyle: .headline)
                content.image = UIImage(systemName: iconName(for: source))
                cell.contentConfiguration = content
                cell.accessoryType = .disclosureIndicator
                return cell
            }

            func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
                let source = sources[indexPath.row]
                frameworks.selectSource(source)
                let sidebar = FrameworkSidebarViewController(model: model, frameworks: frameworks)
                sidebar.title = source.displayName
                navigationController?.pushViewController(sidebar, animated: true)
            }
        }
    }

    public extension UI {
        @MainActor
        static func makeFrameworkBrowser(
            model: RootModel,
            frameworks: any Presentation.FrameworkBrowserViewModelProtocol,
        ) -> UIViewController {
            DatabaseListViewController(model: model, frameworks: frameworks)
        }
    }
#endif
