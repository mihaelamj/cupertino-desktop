import AppCore
import AppModels
import CodeHighlighting
import MarkdownRendering
import PresentationBridge

#if canImport(UIKit)
    import UIKit

    extension UI {
        /// The UIKit detail column. Renders the selected framework's overview document
        /// from `Feature.FrameworkBrowser.ViewModel`, mirroring the SwiftUI detail: a
        /// scrollable text view of the markdown, a spinner while loading, an empty state
        /// otherwise. A reader text-size control rescales the text, and tapping an
        /// in-document link loads that document in place. State changes are picked up with
        /// `withObservationTracking`.
        @MainActor
        final class SelectionDetailViewController: UIViewController, UITextViewDelegate, UITableViewDataSource, UITableViewDelegate {
            private let model: RootModel
            private let frameworks: any Presentation.FrameworkBrowserViewModelProtocol
            private let textView = UITextView()
            private let tableView = UITableView(frame: .zero, style: .insetGrouped)
            private static let documentCellID = "documentCell"

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
                tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.documentCellID)
                tableView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(tableView)

                textView.isEditable = false
                textView.delegate = self
                textView.alwaysBounceVertical = true
                // The text view is clear (the view behind it holds the content-layer
                // background), so the document scrolls under the Liquid Glass navigation bar and
                // the glass refracts the text rather than an opaque panel. See cupertino-desktop #52.
                textView.backgroundColor = .clear
                textView.font = .preferredFont(forTextStyle: .body)
                textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
                textView.translatesAutoresizingMaskIntoConstraints = false
                textView.accessibilityIdentifier = UI.AccessibilityID.FrameworkBrowser.reader
                view.addSubview(textView)

                NSLayoutConstraint.activate([
                    tableView.topAnchor.constraint(equalTo: view.topAnchor),
                    tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                    tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

                    textView.topAnchor.constraint(equalTo: view.topAnchor),
                    textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                    textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                ])

                track()
                render()
            }

            override func viewDidDisappear(_ animated: Bool) {
                super.viewDidDisappear(animated)
                if isMovingFromParent || isBeingDismissed {
                    if splitViewController?.isCollapsed == true {
                        model.selectedFrameworkID = nil
                        frameworks.selectFramework(nil)
                    }
                }
            }

            private func track() {
                withObservationTracking {
                    _ = frameworks.documentState
                    _ = frameworks.documents
                } onChange: { [weak self] in
                    Task { @MainActor in
                        guard let self else { return }
                        self.render()
                        self.track()
                    }
                }
            }

            private func render() {
                if let markdown = frameworks.selectedMarkdown {
                    contentUnavailableConfiguration = nil
                    textView.isHidden = false
                    tableView.isHidden = true
                    let base = Markdown.Theme().basePointSize
                    textView.attributedText = Markdown.attributed(
                        markdown: markdown,
                        title: frameworks.selectedDocumentTitle,
                        highlighter: Highlight.Splash(),
                        theme: Markdown.Theme(basePointSize: base * Model.ReaderTextSize.current),
                    )
                    title = frameworks.selectedDocumentTitle
                } else {
                    textView.isHidden = true
                    if frameworks.isLoadingDocument {
                        tableView.isHidden = true
                        title = frameworks.selectedFramework?.displayName ?? "Loading..."
                        contentUnavailableConfiguration = UIContentUnavailableConfiguration.loading()
                    } else if let error = frameworks.documentError {
                        tableView.isHidden = true
                        title = "Error"
                        contentUnavailableConfiguration = Self.configuration(systemImage: "exclamationmark.triangle", title: "Could not load document", message: error)
                    } else if let selectedFramework = frameworks.selectedFramework {
                        contentUnavailableConfiguration = nil
                        tableView.isHidden = false
                        tableView.reloadData()
                        title = selectedFramework.displayName
                    } else {
                        tableView.isHidden = true
                        title = "Cupertino"
                        let emptyTitle = if let source = frameworks.selectedSource {
                            "Select a \(source.singularItemTerm)"
                        } else {
                            "Select a database"
                        }
                        contentUnavailableConfiguration = Self.configuration(systemImage: "doc.text", title: emptyTitle, message: nil)
                    }
                }

                // The reader text-size control belongs to a loaded document only.
                let hasDocument = frameworks.selectedMarkdown != nil
                navigationItem.rightBarButtonItems = hasDocument
                    ? UI.ReaderTextSize.barButtonItems(target: self, larger: #selector(textLarger), smaller: #selector(textSmaller))
                    : nil
            }

            /// A content-unavailable configuration for the detail's empty and error states.
            private static func configuration(systemImage: String, title: String, message: String?) -> UIContentUnavailableConfiguration {
                var configuration = UIContentUnavailableConfiguration.empty()
                configuration.image = UIImage(systemName: systemImage)
                configuration.text = title
                configuration.secondaryText = message
                return configuration
            }

            @objc private func textLarger() {
                Model.ReaderTextSize.larger()
                refreshSizeControl()
                render()
            }

            @objc private func textSmaller() {
                Model.ReaderTextSize.smaller()
                refreshSizeControl()
                render()
            }

            private func refreshSizeControl() {
                navigationItem.rightBarButtonItems = UI.ReaderTextSize.barButtonItems(
                    target: self, larger: #selector(textLarger), smaller: #selector(textSmaller),
                )
            }

            /// A tapped in-document link that resolves to a doc URI loads in place; other
            /// links (absolute web URLs) open normally.
            func textView(_: UITextView, shouldInteractWith url: URL, in _: NSRange, interaction _: UITextItemInteraction) -> Bool {
                guard let uri = Model.DocURI(url.absoluteString) else { return true }
                frameworks.openDocument(uri)
                return false
            }

            // MARK: - UITableViewDataSource / Delegate

            func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
                frameworks.documents.count
            }

            func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
                let cell = tableView.dequeueReusableCell(withIdentifier: Self.documentCellID, for: indexPath)
                let document = frameworks.documents[indexPath.row]
                cell.accessibilityIdentifier = "document_cell"
                var content = cell.defaultContentConfiguration()
                content.text = document.title
                content.secondaryText = document.snippet
                content.secondaryTextProperties.numberOfLines = 2
                cell.contentConfiguration = content
                cell.accessoryType = .disclosureIndicator
                return cell
            }

            func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
                tableView.deselectRow(at: indexPath, animated: true)
                guard indexPath.row < frameworks.documents.count else { return }
                let hit = frameworks.documents[indexPath.row]
                navigationController?.pushViewController(
                    DocumentReaderViewController(model: frameworks, uri: hit.uri, title: hit.title),
                    animated: true,
                )
            }
        }
    }
#endif
