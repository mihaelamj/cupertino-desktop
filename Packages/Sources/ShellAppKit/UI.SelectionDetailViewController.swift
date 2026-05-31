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
            private let progress = NSProgressIndicator()
            private let emptyState = NSStackView()
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

                progress.style = .spinning
                progress.controlSize = .regular
                progress.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(progress)

                let image = NSImageView()
                image.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
                image.symbolConfiguration = .init(pointSize: 36, weight: .regular)
                image.contentTintColor = .tertiaryLabelColor
                let label = NSTextField(labelWithString: "Select a framework")
                label.font = .systemFont(ofSize: NSFont.systemFontSize + 4, weight: .semibold)
                label.textColor = .secondaryLabelColor
                emptyState.orientation = .vertical
                emptyState.alignment = .centerX
                emptyState.spacing = 8
                emptyState.addArrangedSubview(image)
                emptyState.addArrangedSubview(label)
                emptyState.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(emptyState)

                configureSizeControls()
                container.addSubview(sizeControls)

                NSLayoutConstraint.activate([
                    scrollView.topAnchor.constraint(equalTo: container.topAnchor),
                    scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    sizeControls.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
                    sizeControls.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                    progress.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    progress.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    emptyState.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    emptyState.centerYAnchor.constraint(equalTo: container.centerYAnchor),
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
                progress.isHidden = !loading
                if loading { progress.startAnimation(nil) } else { progress.stopAnimation(nil) }

                if let markdown = frameworks.selectedMarkdown {
                    scrollView.isHidden = false
                    emptyState.isHidden = true
                    let base = Markdown.Theme().basePointSize
                    textView.textStorage?.setAttributedString(Markdown.attributed(
                        markdown: markdown,
                        title: frameworks.selectedDocumentTitle,
                        highlighter: Highlight.Splash(),
                        theme: Markdown.Theme(basePointSize: base * Model.ReaderTextSize.current),
                    ))
                } else if let error = frameworks.documentError {
                    scrollView.isHidden = false
                    emptyState.isHidden = true
                    textView.string = error
                } else {
                    scrollView.isHidden = true
                    emptyState.isHidden = loading
                }
            }
        }
    }
#endif
