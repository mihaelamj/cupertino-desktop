import AppCore
import AppModels
import SearchFeature

#if canImport(UIKit)
    import UIKit

    extension UI {
        /// Reader pushed when a UIKit search result is tapped. It reads the document by
        /// URI through the shared, framework-agnostic `Feature.Search.ViewModel`, the same
        /// view model the SwiftUI and AppKit search screens bind, and renders its full
        /// markdown body. View code only; the read lives behind the protocol seam.
        @MainActor
        final class DocumentReaderViewController: UIViewController {
            private let model: Feature.Search.ViewModel
            private let hit: Model.DocHit
            private let textView = UITextView()
            private let spinner = UIActivityIndicatorView(style: .large)

            init(model: Feature.Search.ViewModel, hit: Model.DocHit) {
                self.model = model
                self.hit = hit
                super.init(nibName: nil, bundle: nil)
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError("init(coder:) is unsupported; this app uses no storyboards.")
            }

            override func viewDidLoad() {
                super.viewDidLoad()
                title = hit.title
                view.backgroundColor = .systemBackground

                textView.isEditable = false
                textView.alwaysBounceVertical = true
                textView.font = .preferredFont(forTextStyle: .body)
                textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
                textView.translatesAutoresizingMaskIntoConstraints = false
                textView.isHidden = true
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

            private func load() {
                spinner.startAnimating()
                Task { @MainActor in
                    defer { spinner.stopAnimating() }
                    do {
                        let page = try await model.readPage(hit.uri)
                        textView.text = page.markdown
                    } catch {
                        textView.text = "Could not open the document."
                    }
                    textView.isHidden = false
                }
            }
        }
    }
#endif
