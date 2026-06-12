import AppCore
import AppModels
import CodeHighlighting
import MarkdownRendering
import PresentationBridge

#if canImport(UIKit)
    import UIKit

    extension UI {
        /// Reader pushed when a UIKit search result (or an in-document link) is opened. It
        /// reads the document by URI through the shared, framework-agnostic
        /// `Feature.Search.ViewModel`, renders its full markdown, carries the reader
        /// text-size control, and pushes a new reader when a link inside the page is tapped.
        @MainActor
        final class DocumentReaderViewController: UIViewController, UITextViewDelegate {
            private let model: any Presentation.DocumentPageReader
            private let uri: Model.DocURI
            private let providedTitle: String?
            private let textView = UITextView()
            private let spinner = UIActivityIndicatorView(style: .large)

            init(model: any Presentation.DocumentPageReader, uri: Model.DocURI, title: String?) {
                self.model = model
                self.uri = uri
                providedTitle = title
                super.init(nibName: nil, bundle: nil)
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError("init(coder:) is unsupported; this app uses no storyboards.")
            }

            override func viewDidLoad() {
                super.viewDidLoad()
                title = providedTitle
                view.backgroundColor = .systemBackground
                refreshSizeControl()

                textView.isEditable = false
                textView.delegate = self
                textView.alwaysBounceVertical = true
                // Clear text view over the content-layer background, so the document scrolls
                // under the Liquid Glass navigation bar and the glass refracts the text rather
                // than an opaque panel. See cupertino-desktop #52.
                textView.backgroundColor = .clear
                textView.font = .preferredFont(forTextStyle: .body)
                textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
                textView.translatesAutoresizingMaskIntoConstraints = false
                textView.isHidden = true
                textView.accessibilityIdentifier = UI.AccessibilityID.FrameworkBrowser.reader
                view.addSubview(textView)

                spinner.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(spinner)

                NSLayoutConstraint.activate([
                    textView.topAnchor.constraint(equalTo: view.topAnchor),
                    textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                    textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                ])

                load()
            }

            private var page: Model.DocPage?

            private func load() {
                spinner.startAnimating()
                Task { @MainActor in
                    defer { spinner.stopAnimating() }
                    do {
                        let loaded = try await model.readPage(uri)
                        page = loaded
                        if title == nil { title = loaded.title }
                        render()
                    } catch {
                        textView.text = "Could not open the document."
                    }
                    textView.isHidden = false
                }
            }

            private func render() {
                guard let page else { return }
                let base = Markdown.Theme().basePointSize
                textView.attributedText = Markdown.attributed(
                    page: page,
                    highlighter: Highlight.Splash(),
                    theme: Markdown.Theme(basePointSize: base * Model.ReaderTextSize.current),
                )
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

            /// A tapped in-document link that resolves to a doc URI pushes a new reader;
            /// other links open normally.
            func textView(_: UITextView, shouldInteractWith url: URL, in _: NSRange, interaction _: UITextItemInteraction) -> Bool {
                guard let linked = Model.DocURI(url.absoluteString) else { return true }
                navigationController?.pushViewController(
                    DocumentReaderViewController(model: model, uri: linked, title: nil), animated: true,
                )
                return false
            }
        }
    }
#endif
