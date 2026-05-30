import AppCore

#if canImport(UIKit)
    import UIKit

    extension UI {
        /// The UIKit detail column. Mirrors the SwiftUI and AppKit shells one-to-one:
        /// the selected framework id when one is chosen, the "Select a document" empty
        /// state otherwise. Observes `RootModel.selectedFrameworkID` with
        /// `withObservationTracking`, the UIKit equivalent of SwiftUI's automatic
        /// binding. Replaced by the real document reader in a later milestone.
        @MainActor
        final class SelectionDetailViewController: UIViewController {
            private let model: RootModel
            private let idLabel = UILabel()
            private let emptyState = UIStackView()

            init(model: RootModel) {
                self.model = model
                super.init(nibName: nil, bundle: nil)
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError("init(coder:) is unsupported; this app uses no storyboards.")
            }

            override func viewDidLoad() {
                super.viewDidLoad()
                view.backgroundColor = .systemBackground

                idLabel.font = .preferredFont(forTextStyle: .title2)
                idLabel.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(idLabel)

                let image = UIImageView(image: UIImage(systemName: "doc.text"))
                image.tintColor = .tertiaryLabel
                image.contentMode = .scaleAspectFit
                image.preferredSymbolConfiguration = .init(pointSize: 36, weight: .regular)
                let title = UILabel()
                title.text = "Select a document"
                title.font = .preferredFont(forTextStyle: .headline)
                title.textColor = .secondaryLabel
                emptyState.axis = .vertical
                emptyState.alignment = .center
                emptyState.spacing = 8
                emptyState.addArrangedSubview(image)
                emptyState.addArrangedSubview(title)
                emptyState.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(emptyState)

                NSLayoutConstraint.activate([
                    idLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    idLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    emptyState.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    emptyState.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                ])

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
                    idLabel.text = id
                    idLabel.isHidden = false
                    emptyState.isHidden = true
                    title = id
                } else {
                    idLabel.isHidden = true
                    emptyState.isHidden = false
                    title = nil
                }
            }
        }
    }
#endif
