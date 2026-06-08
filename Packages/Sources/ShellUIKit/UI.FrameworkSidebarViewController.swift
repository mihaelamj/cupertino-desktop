import AppCore
import AppModels
import FrameworkBrowserFeature

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
        final class FrameworkSidebarViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
            private let model: RootModel
            private let frameworks: Feature.FrameworkBrowser.ViewModel

            private let tableView = UITableView(frame: .zero, style: .insetGrouped)
            private static let cellID = "framework"

            init(model: RootModel, frameworks: Feature.FrameworkBrowser.ViewModel) {
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

                // Loading and error are shown as a system content-unavailable view (the UIKit
                // counterpart of SwiftUI's `ContentUnavailableView`), so all three UIs present
                // the same empty/error state; the table is shown only once frameworks load.
                if isLoading {
                    contentUnavailableConfiguration = UIContentUnavailableConfiguration.loading()
                } else if let error {
                    contentUnavailableConfiguration = Self.errorConfiguration(message: error) { [weak self] in
                        self?.frameworks.onRetried()
                    }
                } else {
                    contentUnavailableConfiguration = nil
                }
                tableView.isHidden = isLoading || error != nil

                tableView.reloadData()
                syncSelectionFromModel()
            }

            /// A content-unavailable configuration for the load-failure state: an icon, the
            /// "Could not load frameworks" title, the backend's message (e.g. the install
            /// hint when cupertino is not installed), and a Retry button.
            private static func errorConfiguration(message: String, retry: @escaping () -> Void) -> UIContentUnavailableConfiguration {
                var configuration = UIContentUnavailableConfiguration.empty()
                configuration.image = UIImage(systemName: "exclamationmark.triangle")
                configuration.text = "Could not load frameworks"
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
                splitViewController?.show(.secondary)
            }
        }
    }
#endif
