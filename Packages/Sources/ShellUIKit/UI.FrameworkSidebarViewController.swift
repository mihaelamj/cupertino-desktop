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
            private let spinner = UIActivityIndicatorView(style: .medium)
            private let statusLabel = UILabel()
            private let retryButton = UIButton(type: .system)
            private let statusStack = UIStackView()
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
                tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellID)
                tableView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(tableView)

                statusLabel.textColor = .secondaryLabel
                statusLabel.textAlignment = .center
                statusLabel.numberOfLines = 0
                retryButton.setTitle("Retry", for: .normal)
                retryButton.addTarget(self, action: #selector(onRetryTapped), for: .touchUpInside)
                statusStack.axis = .vertical
                statusStack.alignment = .center
                statusStack.spacing = 8
                statusStack.addArrangedSubview(spinner)
                statusStack.addArrangedSubview(statusLabel)
                statusStack.addArrangedSubview(retryButton)
                statusStack.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(statusStack)

                NSLayoutConstraint.activate([
                    tableView.topAnchor.constraint(equalTo: view.topAnchor),
                    tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                    tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    statusStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    statusStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    statusStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
                    statusStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),
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

                spinner.isHidden = !isLoading
                if isLoading { spinner.startAnimating() } else { spinner.stopAnimating() }
                statusLabel.isHidden = !isLoading && error == nil
                retryButton.isHidden = error == nil
                statusStack.isHidden = !isLoading && error == nil
                tableView.isHidden = isLoading || error != nil

                if isLoading {
                    statusLabel.text = "Loading frameworks"
                } else if let error {
                    statusLabel.text = error
                }

                tableView.reloadData()
                syncSelectionFromModel()
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

            @objc private func onRetryTapped() {
                frameworks.onRetried()
            }

            // MARK: UITableViewDataSource / Delegate

            func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
                frameworks.frameworks.count
            }

            func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
                let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellID, for: indexPath)
                let framework = frameworks.frameworks[indexPath.row]

                var content = cell.defaultContentConfiguration()
                content.text = framework.name
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
                model.selectedFrameworkID = frameworks.frameworks[indexPath.row].id
                splitViewController?.show(.secondary)
            }
        }
    }
#endif
