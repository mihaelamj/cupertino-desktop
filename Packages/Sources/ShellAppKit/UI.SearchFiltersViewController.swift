import AppCore
import AppModels
import SearchFeature

#if canImport(AppKit)
    import AppKit

    extension UI {
        /// The AppKit filters popover, the counterpart of the SwiftUI search `Filters`
        /// form and the UIKit filters sheet: the eight source databases as checkboxes,
        /// the framework and per-platform minimum fields, and a result limit. It binds
        /// the shared `Feature.Search.ViewModel`; applying re-runs the same query the
        /// other UIs run. View code only.
        @MainActor
        final class SearchFiltersViewController: NSViewController {
            private let model: Feature.Search.ViewModel
            private let onApply: () -> Void
            private var sourceCheckboxes: [(Model.Source, NSButton)] = []
            private let frameworkField = NSTextField()
            private let minIOSField = NSTextField()
            private let minMacOSField = NSTextField()
            private let minSwiftField = NSTextField()
            private let limitLabel = NSTextField(labelWithString: "")
            private let limitStepper = NSStepper()

            init(model: Feature.Search.ViewModel, onApply: @escaping () -> Void) {
                self.model = model
                self.onApply = onApply
                super.init(nibName: nil, bundle: nil)
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError("init(coder:) is unsupported; this app uses no XIBs.")
            }

            override func loadView() {
                let stack = NSStackView()
                stack.orientation = .vertical
                stack.alignment = .leading
                stack.spacing = 8
                stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

                stack.addArrangedSubview(header("Databases"))
                for source in Model.Source.allCases {
                    let checkbox = NSButton(checkboxWithTitle: source.scheme, target: self, action: #selector(toggleSource(_:)))
                    checkbox.state = model.sources.contains(source) ? .on : .off
                    sourceCheckboxes.append((source, checkbox))
                    stack.addArrangedSubview(checkbox)
                }

                stack.addArrangedSubview(header("Filters"))
                stack.addArrangedSubview(labeledField("Framework", frameworkField, value: model.framework, placeholder: "e.g. SwiftUI"))
                stack.addArrangedSubview(labeledField("min iOS", minIOSField, value: model.minIOS, placeholder: "e.g. 17.0"))
                stack.addArrangedSubview(labeledField("min macOS", minMacOSField, value: model.minMacOS, placeholder: "e.g. 14.0"))
                stack.addArrangedSubview(labeledField("min Swift", minSwiftField, value: model.minSwift, placeholder: "e.g. 5.9"))

                stack.addArrangedSubview(header("Limit"))
                limitStepper.minValue = 1
                limitStepper.maxValue = 100
                limitStepper.integerValue = model.limit
                limitStepper.target = self
                limitStepper.action = #selector(limitChanged)
                limitLabel.stringValue = "Limit: \(model.limit)"
                let limitRow = NSStackView(views: [limitLabel, limitStepper])
                limitRow.orientation = .horizontal
                limitRow.spacing = 8
                stack.addArrangedSubview(limitRow)

                let apply = NSButton(title: "Apply", target: self, action: #selector(apply))
                apply.bezelStyle = .rounded
                apply.keyEquivalent = "\r"
                stack.addArrangedSubview(apply)

                stack.translatesAutoresizingMaskIntoConstraints = false
                let container = NSView()
                container.addSubview(stack)
                NSLayoutConstraint.activate([
                    stack.topAnchor.constraint(equalTo: container.topAnchor),
                    stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    container.widthAnchor.constraint(equalToConstant: 280),
                ])
                view = container
            }

            private func header(_ title: String) -> NSTextField {
                let label = NSTextField(labelWithString: title)
                label.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
                label.textColor = .secondaryLabelColor
                return label
            }

            private func labeledField(_ title: String, _ field: NSTextField, value: String, placeholder: String) -> NSView {
                let label = NSTextField(labelWithString: title)
                label.alignment = .right
                label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
                field.stringValue = value
                field.placeholderString = placeholder
                field.translatesAutoresizingMaskIntoConstraints = false
                field.widthAnchor.constraint(equalToConstant: 140).isActive = true
                let row = NSStackView(views: [label, field])
                row.orientation = .horizontal
                row.spacing = 8
                return row
            }

            // MARK: Actions

            @objc private func toggleSource(_ sender: NSButton) {
                guard let pair = sourceCheckboxes.first(where: { $0.1 == sender }) else { return }
                model.toggle(pair.0)
            }

            @objc private func limitChanged() {
                model.limit = limitStepper.integerValue
                limitLabel.stringValue = "Limit: \(model.limit)"
            }

            @objc private func apply() {
                model.framework = frameworkField.stringValue
                model.minIOS = minIOSField.stringValue
                model.minMacOS = minMacOSField.stringValue
                model.minSwift = minSwiftField.stringValue
                onApply()
            }
        }
    }
#endif
