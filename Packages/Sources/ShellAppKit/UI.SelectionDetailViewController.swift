import AppCore
import FrameworkBrowserFeature

#if canImport(AppKit)
    import AppKit

    extension UI {
        /// The AppKit detail column. Renders the selected framework's overview document
        /// from `Feature.FrameworkBrowser.ViewModel`, mirroring the SwiftUI and UIKit
        /// detail: a scrollable text view of the markdown, a spinner while loading, an
        /// empty state otherwise. Observes the view model with `withObservationTracking`.
        @MainActor
        final class SelectionDetailViewController: NSViewController {
            private let frameworks: Feature.FrameworkBrowser.ViewModel
            private let scrollView = NSScrollView()
            private let textView = NSTextView()
            private let progress = NSProgressIndicator()
            private let emptyState = NSStackView()

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

                NSLayoutConstraint.activate([
                    scrollView.topAnchor.constraint(equalTo: container.topAnchor),
                    scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    progress.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    progress.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    emptyState.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    emptyState.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                ])
                view = container
            }

            override func viewDidLoad() {
                super.viewDidLoad()
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
                progress.isHidden = !loading
                if loading { progress.startAnimation(nil) } else { progress.stopAnimation(nil) }

                if let markdown = frameworks.selectedMarkdown {
                    scrollView.isHidden = false
                    emptyState.isHidden = true
                    textView.string = markdown
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
