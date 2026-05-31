import AppCore
import AppModels
import CodeHighlighting
import FrameworkBrowserFeature
import MarkdownRendering

#if canImport(AppKit)
    import AppKit

    extension UI {
        /// The AppKit detail column. Renders the selected framework's overview document
        /// from `Feature.FrameworkBrowser.ViewModel`, mirroring the SwiftUI and UIKit
        /// detail: a scrollable text view of the markdown, a spinner while loading, an
        /// empty state otherwise. A floating text-size control rescales the text (macOS has
        /// no Dynamic Type, so this is the resize mechanism here), and tapping an
        /// in-document link loads that document in place. Observes the view model with
        /// `withObservationTracking`.
        @MainActor
        final class SelectionDetailViewController: NSViewController, NSTextViewDelegate {
            private let frameworks: Feature.FrameworkBrowser.ViewModel
            private let scrollView = NSScrollView()
            private let textView = NSTextView()
            // The loading, empty, and error states all render through the native
            // `ContentUnavailableView` replica, matching the SwiftUI and UIKit detail.
            private let unavailable = UI.ContentUnavailableView()
            private let sizeControls = NSStackView()

            init(frameworks: Feature.FrameworkBrowser.ViewModel) {
                self.frameworks = frameworks
                super.init(nibName: nil, bundle: nil)
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError("init(coder:) is unsupported; this app uses no XIBs.")
            }

            override func loadView() {
                let container = NSView()

                textView.isEditable = false
                textView.drawsBackground = false
                textView.textContainerInset = NSSize(width: 16, height: 16)
                textView.font = .systemFont(ofSize: NSFont.systemFontSize)
                textView.setAccessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.reader)
                scrollView.documentView = textView
                scrollView.hasVerticalScroller = true
                scrollView.drawsBackground = false
                scrollView.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(scrollView)

                unavailable.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(unavailable)

                configureSizeControls()
                container.addSubview(sizeControls)

                NSLayoutConstraint.activate([
                    scrollView.topAnchor.constraint(equalTo: container.topAnchor),
                    scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    unavailable.topAnchor.constraint(equalTo: container.topAnchor),
                    unavailable.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    unavailable.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    unavailable.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    sizeControls.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
                    sizeControls.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                ])
                view = container
            }

            private func configureSizeControls() {
                let smaller = sizeButton("textformat.size.smaller", action: #selector(textSmaller), tip: "Smaller text")
                let larger = sizeButton("textformat.size.larger", action: #selector(textLarger), tip: "Larger text")
                smaller.setAccessibilityIdentifier(UI.AccessibilityID.Reader.textSmaller)
                larger.setAccessibilityIdentifier(UI.AccessibilityID.Reader.textLarger)
                sizeControls.orientation = .horizontal
                sizeControls.spacing = 4
                sizeControls.addArrangedSubview(smaller)
                sizeControls.addArrangedSubview(larger)
                sizeControls.translatesAutoresizingMaskIntoConstraints = false
            }

            private func sizeButton(_ symbol: String, action: Selector, tip: String) -> NSButton {
                let button = NSButton(
                    image: NSImage(systemSymbolName: symbol, accessibilityDescription: tip) ?? NSImage(),
                    target: self, action: action,
                )
                button.bezelStyle = .texturedRounded
                button.toolTip = tip
                return button
            }

            override func viewDidLoad() {
                super.viewDidLoad()
                textView.delegate = self
                track()
                render()
            }

            @objc private func textLarger() {
                Model.ReaderTextSize.larger()
                render()
            }

            @objc private func textSmaller() {
                Model.ReaderTextSize.smaller()
                render()
            }

            /// A clicked in-document link that resolves to a doc URI loads in place; other
            /// links fall through to the system.
            func textView(_: NSTextView, clickedOnLink link: Any, at _: Int) -> Bool {
                let urlString = (link as? URL)?.absoluteString ?? (link as? String)
                guard let urlString, let uri = Model.DocURI(urlString) else { return false }
                frameworks.openDocument(uri)
                return true
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

                if let markdown = frameworks.selectedMarkdown {
                    let base = Markdown.Theme().basePointSize
                    textView.textStorage?.setAttributedString(Markdown.attributed(
                        markdown: markdown,
                        title: frameworks.selectedDocumentTitle,
                        highlighter: Highlight.Splash(),
                        theme: Markdown.Theme(basePointSize: base * Model.ReaderTextSize.current),
                    ))
                } else if loading {
                    unavailable.showLoading()
                } else if let error = frameworks.documentError {
                    unavailable.show(systemImage: "exclamationmark.triangle", title: "Could not load document", message: error)
                } else {
                    unavailable.show(systemImage: "doc.text", title: "Select a framework")
                }

                // The reader (and its text-size control) shows only with a loaded document;
                // every other state is the content-unavailable view.
                let hasDocument = frameworks.selectedMarkdown != nil
                scrollView.isHidden = !hasDocument
                sizeControls.isHidden = !hasDocument
                unavailable.isHidden = hasDocument
            }
        }
    }
#endif
