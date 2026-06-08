import AppCore

#if canImport(AppKit)
    import AppKit

    extension UI {
        /// AppKit ships no `ContentUnavailableView` (SwiftUI) or `UIContentUnavailableConfiguration`
        /// (UIKit), so this is the native equivalent and it imitates that style: a vertically
        /// centered large, muted SF Symbol, a semibold title, an optional secondary message, and
        /// an optional action button, plus a loading mode (a spinner and label). It is the single
        /// view behind every empty / error / loading state in the AppKit shell, so the AppKit app
        /// presents the same states as the SwiftUI and UIKit apps with the same symbols.
        @MainActor
        final class ContentUnavailableView: NSView {
            private let spinner = NSProgressIndicator()
            private let imageView = NSImageView()
            private let titleLabel = NSTextField(labelWithString: "")
            private let messageLabel = NSTextField(labelWithString: "")
            private let button = NSButton()
            private let stack = NSStackView()
            private var action: (() -> Void)?

            init() {
                super.init(frame: .zero)
                configure()
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError("init(coder:) is unsupported; this app uses no XIBs.")
            }

            private func configure() {
                spinner.style = .spinning
                spinner.isIndeterminate = true
                spinner.controlSize = .regular

                // Match ContentUnavailableView's rendering: a large, muted symbol; a large
                // bold title in the SECONDARY label color (not primary); a secondary message.
                imageView.symbolConfiguration = .init(pointSize: 52, weight: .regular)
                imageView.contentTintColor = .secondaryLabelColor
                imageView.imageScaling = .scaleNone

                titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
                titleLabel.textColor = .secondaryLabelColor
                titleLabel.alignment = .center
                titleLabel.maximumNumberOfLines = 0

                messageLabel.font = .systemFont(ofSize: NSFont.systemFontSize + 1)
                messageLabel.textColor = .secondaryLabelColor
                messageLabel.alignment = .center
                messageLabel.maximumNumberOfLines = 0

                button.bezelStyle = .rounded
                button.target = self
                button.action = #selector(onButtonTapped)

                stack.orientation = .vertical
                stack.alignment = .centerX
                stack.spacing = 8
                stack.addArrangedSubview(spinner)
                stack.addArrangedSubview(imageView)
                stack.addArrangedSubview(titleLabel)
                stack.addArrangedSubview(messageLabel)
                stack.addArrangedSubview(button)
                stack.setCustomSpacing(16, after: spinner)
                stack.setCustomSpacing(16, after: imageView)
                stack.setCustomSpacing(16, after: messageLabel)
                stack.translatesAutoresizingMaskIntoConstraints = false
                addSubview(stack)

                NSLayoutConstraint.activate([
                    stack.centerXAnchor.constraint(equalTo: centerXAnchor),
                    stack.centerYAnchor.constraint(equalTo: centerYAnchor),
                    stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
                    stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
                    stack.widthAnchor.constraint(lessThanOrEqualToConstant: 360),
                ])
            }

            /// Present an empty or error state: a symbol, a title, an optional message, and an
            /// optional action button.
            func show(systemImage: String, title: String, message: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
                spinner.stopAnimation(nil)
                spinner.isHidden = true
                imageView.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)
                imageView.isHidden = false
                titleLabel.stringValue = title
                titleLabel.isHidden = false
                messageLabel.stringValue = message ?? ""
                messageLabel.isHidden = message == nil
                self.action = action
                button.title = actionTitle ?? ""
                button.isHidden = actionTitle == nil
            }

            /// Present a loading state: a spinner with an optional label (the detail column
            /// shows a bare spinner, matching the SwiftUI `ProgressView()`).
            func showLoading(title: String? = nil) {
                imageView.isHidden = true
                messageLabel.isHidden = true
                button.isHidden = true
                action = nil
                spinner.isHidden = false
                spinner.startAnimation(nil)
                titleLabel.stringValue = title ?? ""
                titleLabel.isHidden = title == nil
            }

            @objc private func onButtonTapped() {
                action?()
            }
        }
    }
#endif
