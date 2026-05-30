import AppCore

#if canImport(AppKit)
    import AppKit

    extension UI {
        /// The AppKit detail column. It mirrors the SwiftUI shell one-to-one: when a
        /// framework is selected it shows the id (the same minimal content SwiftUI
        /// shows via `Text(id)`), otherwise the "Select a document" empty state. It
        /// observes `RootModel.selectedFrameworkID` with `withObservationTracking`, the
        /// AppKit equivalent of SwiftUI's automatic binding. Replaced by the real
        /// document reader in a later milestone.
        @MainActor
        final class SelectionDetailViewController: NSViewController {
            private let model: RootModel
            private let idLabel = NSTextField(labelWithString: "")
            private let emptyState = NSStackView()

            init(model: RootModel) {
                self.model = model
                super.init(nibName: nil, bundle: nil)
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError("init(coder:) is unsupported; this app uses no XIBs.")
            }

            override func loadView() {
                let container = NSView()

                idLabel.font = .systemFont(ofSize: NSFont.systemFontSize + 6, weight: .semibold)
                idLabel.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(idLabel)

                let image = NSImageView()
                image.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
                image.symbolConfiguration = .init(pointSize: 36, weight: .regular)
                image.contentTintColor = .tertiaryLabelColor
                let title = NSTextField(labelWithString: "Select a document")
                title.font = .systemFont(ofSize: NSFont.systemFontSize + 4, weight: .semibold)
                title.textColor = .secondaryLabelColor
                emptyState.orientation = .vertical
                emptyState.alignment = .centerX
                emptyState.spacing = 8
                emptyState.addArrangedSubview(image)
                emptyState.addArrangedSubview(title)
                emptyState.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(emptyState)

                NSLayoutConstraint.activate([
                    idLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    idLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
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
                    _ = model.selectedFrameworkID
                } onChange: { [weak self] in
                    Task { @MainActor in
                        guard let self else { return }
                        self.render()
                        self.track()
                    }
                }
            }

            private func render() {
                if let id = model.selectedFrameworkID {
                    idLabel.stringValue = id
                    idLabel.isHidden = false
                    emptyState.isHidden = true
                } else {
                    idLabel.isHidden = true
                    emptyState.isHidden = false
                }
            }
        }
    }
#endif
