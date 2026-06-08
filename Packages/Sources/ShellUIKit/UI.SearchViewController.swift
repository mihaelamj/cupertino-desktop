import AppCore
import AppModels
import SearchFeature

#if canImport(UIKit)
    import UIKit

    public extension UI {
        /// Build the UIKit search screen as a base view controller, so an app target can
        /// drop it into a tab without seeing the concrete class (mirrors how the framework
        /// browser is reached through `RootExperience`). It binds the shared, framework-
        /// agnostic `Feature.Search.ViewModel`.
        @MainActor
        static func makeSearch(model: Feature.Search.ViewModel) -> UIViewController {
            SearchViewController(model: model)
        }
    }

    extension UI {
        /// The UIKit search screen, the one-to-one counterpart of the SwiftUI
        /// `UI.SearchView`: a search bar with a Docs/Everything scope, a results table
        /// (one list for Docs; source-bucketed sections for Everything), and a Filters
        /// button. It binds the shared, framework-agnostic `Feature.Search.ViewModel`,
        /// the exact same view model the SwiftUI and AppKit search screens use, and holds
        /// no logic. State changes are picked up with `withObservationTracking`, the
        /// UIKit equivalent of SwiftUI's automatic `@Observable` tracking. Live search is
        /// debounced through the view model so a real backend is not hit per keystroke.
        @MainActor
        final class SearchViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating, UISearchBarDelegate {
            private let model: Feature.Search.ViewModel
            private let tableView = UITableView(frame: .zero, style: .insetGrouped)
            private let searchController = UISearchController(searchResultsController: nil)
            private let emptyLabel = UILabel()

            /// A flattened snapshot of what the table shows, rebuilt on every state change.
            private enum Row {
                case leaf(Feature.Search.ResultNode)
                case doc(Model.DocHit)
                case sample(Model.SampleProject)
                case package(Model.PackageHit)
            }

            private var sections: [(title: String?, rows: [Row])] = []

            init(model: Feature.Search.ViewModel) {
                self.model = model
                super.init(nibName: nil, bundle: nil)
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError("init(coder:) is unsupported; this app uses no storyboards.")
            }

            override func viewDidLoad() {
                super.viewDidLoad()
                title = "Search"
                view.backgroundColor = .systemBackground

                searchController.searchResultsUpdater = self
                searchController.searchBar.delegate = self
                searchController.obscuresBackgroundDuringPresentation = false
                searchController.searchBar.placeholder = "Search documentation"
                searchController.searchBar.scopeButtonTitles = ["Docs", "Everything"]
                navigationItem.searchController = searchController
                navigationItem.hidesSearchBarWhenScrolling = false
                navigationItem.rightBarButtonItem = UIBarButtonItem(
                    image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
                    style: .plain, target: self, action: #selector(showFilters),
                )

                tableView.dataSource = self
                tableView.delegate = self
                tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
                tableView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(tableView)

                emptyLabel.text = "Search documentation"
                emptyLabel.textColor = .secondaryLabel
                emptyLabel.textAlignment = .center
                emptyLabel.numberOfLines = 0
                tableView.backgroundView = emptyLabel

                NSLayoutConstraint.activate([
                    tableView.topAnchor.constraint(equalTo: view.topAnchor),
                    tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                    tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                ])

                track()
                if !model.hasRun { model.run() }
                render()
            }

            // MARK: Observation

            private func track() {
                withObservationTracking {
                    _ = model.state
                } onChange: { [weak self] in
                    Task { @MainActor in
                        guard let self else { return }
                        self.render()
                        self.track()
                    }
                }
            }

            private func render() {
                sections = Self.makeSections(model)
                let hasResults = sections.contains { !$0.rows.isEmpty }
                emptyLabel.text = emptyText
                emptyLabel.isHidden = hasResults
                tableView.reloadData()
            }

            private var emptyText: String {
                if model.isLoading { return "Searching..." }
                if let error = model.errorMessage { return error }
                if model.hasRun { return "No matches. Adjust the query or the filters." }
                return "Search documentation"
            }

            private static func makeSections(_ model: Feature.Search.ViewModel) -> [(title: String?, rows: [Row])] {
                switch model.scope {
                case .docs:
                    return model.docsTree.map { group in
                        ("\(group.title) (\(group.children.count))", group.children.map(Row.leaf))
                    }
                case .everything:
                    guard let unified = model.unified else { return [] }
                    var built: [(title: String?, rows: [Row])] = []
                    if !unified.docs.isEmpty { built.append(("Docs (\(unified.docs.count))", unified.docs.map(Row.doc))) }
                    if !unified.samples.projects.isEmpty {
                        built.append(("Samples (\(unified.samples.projects.count))", unified.samples.projects.map(Row.sample)))
                    }
                    if !unified.packages.isEmpty { built.append(("Packages (\(unified.packages.count))", unified.packages.map(Row.package))) }
                    return built
                }
            }

            // MARK: Actions

            @objc private func showFilters() {
                let filters = SearchFiltersViewController(model: model)
                present(UINavigationController(rootViewController: filters), animated: true)
            }

            // MARK: UISearchResultsUpdating / UISearchBarDelegate

            func updateSearchResults(for searchController: UISearchController) {
                model.text = searchController.searchBar.text ?? ""
                model.runDebounced()
            }

            func searchBar(_: UISearchBar, selectedScopeButtonIndexDidChange index: Int) {
                model.scope = index == 1 ? .everything : .docs
                model.run()
            }

            func searchBarSearchButtonClicked(_: UISearchBar) {
                model.run()
            }

            // MARK: UITableViewDataSource / Delegate

            func numberOfSections(in _: UITableView) -> Int {
                sections.count
            }

            func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
                sections[section].rows.count
            }

            func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
                sections[section].title
            }

            func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
                let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
                var content = cell.defaultContentConfiguration()
                switch sections[indexPath.section].rows[indexPath.row] {
                case let .leaf(node):
                    content.text = node.title
                    content.secondaryText = node.subtitle
                    cell.accessoryType = .disclosureIndicator
                    cell.selectionStyle = .default
                case let .doc(hit):
                    content.text = hit.title
                    content.secondaryText = [hit.framework, hit.snippet.isEmpty ? nil : hit.snippet]
                        .compactMap(\.self).joined(separator: " : ")
                    cell.accessoryType = .disclosureIndicator
                    cell.selectionStyle = .default
                case let .sample(project):
                    content.text = project.title
                    content.secondaryText = project.summary
                    cell.accessoryType = .none
                    cell.selectionStyle = .none
                case let .package(hit):
                    content.text = hit.title
                    content.secondaryText = "\(hit.owner)/\(hit.repo)"
                    cell.accessoryType = .none
                    cell.selectionStyle = .none
                }
                content.secondaryTextProperties.numberOfLines = 2
                cell.contentConfiguration = content
                return cell
            }

            func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
                tableView.deselectRow(at: indexPath, animated: true)
                switch sections[indexPath.section].rows[indexPath.row] {
                case let .leaf(node):
                    guard let uri = node.uri else { return }
                    navigationController?.pushViewController(
                        DocumentReaderViewController(model: model, uri: uri, title: node.title),
                        animated: true,
                    )
                case let .doc(hit):
                    navigationController?.pushViewController(DocumentReaderViewController(model: model, uri: hit.uri, title: hit.title), animated: true)
                case .sample, .package:
                    break
                }
            }
        }
    }
#endif
