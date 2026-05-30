import AppCore
import AppModels
import CodeHighlighting
import FrameworkBrowserFeature
import MarkdownRendering

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
        final class SelectionDetailViewController: UIViewController, UITextViewDelegate {
            private let frameworks: Feature.FrameworkBrowser.ViewModel
            private let textView = UITextView()
            private let spinner = UIActivityIndicatorView(style: .medium)
            private let emptyState = UIStackView()

            init(frameworks: Feature.FrameworkBrowser.ViewModel) {
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
                navigationItem.rightBarButtonItems = UI.ReaderTextSize.barButtonItems(target: self, larger: #selector(textLarger), smaller: #selector(textSmaller))

                textView.isEditable = false
                textView.delegate = self
                textView.alwaysBounceVertical = true
                textView.font = .preferredFont(forTextStyle: .body)
                textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
                textView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(textView)

                spinner.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(spinner)

                let image = UIImageView(image: UIImage(systemName: "doc.text"))
                image.tintColor = .tertiaryLabel
                image.contentMode = .scaleAspectFit
                image.preferredSymbolConfiguration = .init(pointSize: 36, weight: .regular)
                let label = UILabel()
                label.text = "Select a framework"
                label.font = .preferredFont(forTextStyle: .headline)
                label.textColor = .secondaryLabel
                emptyState.axis = .vertical
                emptyState.alignment = .center
                emptyState.spacing = 8
                emptyState.addArrangedSubview(image)
                emptyState.addArrangedSubview(label)
                emptyState.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(emptyState)

                NSLayoutConstraint.activate([
                    textView.topAnchor.constraint(equalTo: view.topAnchor),
                    textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                    textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    emptyState.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    emptyState.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                ])

                track()
                render()
            }

            private func track() {
                withObservationTracking {
                    _ = frameworks.documentState
                } onChange: { [weak self] in
                    Task { @MainActor in
                        guard let self else { return }
                        self.render()
                        self.track()
                    }
                }
            }

            private func render() {
                let loading = frameworks.isLoadingDocument
                spinner.isHidden = !loading
                if loading { spinner.startAnimating() } else { spinner.stopAnimating() }

                if let markdown = frameworks.selectedMarkdown {
                    textView.isHidden = false
                    emptyState.isHidden = true
                    let base = Markdown.Theme().basePointSize
                    textView.attributedText = Markdown.attributed(
                        markdown: markdown,
                        title: frameworks.selectedDocumentTitle,
                        highlighter: Highlight.Splash(),
                        theme: Markdown.Theme(basePointSize: base * Model.ReaderTextSize.current),
                    )
                    title = frameworks.selectedDocumentTitle
                } else if let error = frameworks.documentError {
                    textView.isHidden = false
                    emptyState.isHidden = true
                    textView.text = error
                    title = nil
                } else {
                    textView.isHidden = true
                    emptyState.isHidden = loading
                    title = nil
                }
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
        }
    }
#endif
