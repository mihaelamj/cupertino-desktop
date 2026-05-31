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
                    textView.topAnchor.constraint(equalTo: view.topAnchor),
                    textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                    textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
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
                if let markdown = frameworks.selectedMarkdown {
                    contentUnavailableConfiguration = nil
                    textView.isHidden = false
                    let base = Markdown.Theme().basePointSize
                    textView.attributedText = Markdown.attributed(
                        markdown: markdown,
                        title: frameworks.selectedDocumentTitle,
                        highlighter: Highlight.Splash(),
                        theme: Markdown.Theme(basePointSize: base * Model.ReaderTextSize.current),
                    )
                    title = frameworks.selectedDocumentTitle
                } else {
                    // Loading, error, and empty all render as a system content-unavailable view
                    // (matching the SwiftUI and AppKit detail); the reader text view is hidden.
                    textView.isHidden = true
                    title = nil
                    if frameworks.isLoadingDocument {
                        contentUnavailableConfiguration = UIContentUnavailableConfiguration.loading()
                    } else if let error = frameworks.documentError {
                        contentUnavailableConfiguration = Self.configuration(systemImage: "exclamationmark.triangle", title: "Could not load document", message: error)
                    } else {
                        contentUnavailableConfiguration = Self.configuration(systemImage: "doc.text", title: "Select a framework", message: nil)
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
        }
    }
#endif
