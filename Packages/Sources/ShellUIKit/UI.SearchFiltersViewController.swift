import AppCore
import AppModels
import SearchFeature

#if canImport(UIKit)
    import UIKit

    extension UI {
        /// The UIKit filters sheet, the counterpart of the SwiftUI search `Filters` form:
        /// the eight sources as toggles, the framework and per-platform minimum
        /// fields, and a result limit. It binds the shared `Feature.Search.ViewModel`, so
        /// applying re-runs the same query the other UIs run. View code only.
        @MainActor
        final class SearchFiltersViewController: UITableViewController, UITextFieldDelegate {
            private let model: Feature.Search.ViewModel
            private let sources = Model.Source.allCases

            /// One editable text row: its label, the current value, and where to write it.
            private struct Field {
                let title: String
                let placeholder: String
                let value: () -> String
                let apply: (String) -> Void
            }

            private let fields: [Field]

            init(model: Feature.Search.ViewModel) {
                self.model = model
                fields = [
                    Field(title: "Framework", placeholder: "e.g. SwiftUI", value: { model.framework }, apply: { model.framework = $0 }),
                    Field(title: "min iOS", placeholder: "e.g. 17.0", value: { model.minIOS }, apply: { model.minIOS = $0 }),
                    Field(title: "min macOS", placeholder: "e.g. 14.0", value: { model.minMacOS }, apply: { model.minMacOS = $0 }),
                    Field(title: "min Swift", placeholder: "e.g. 5.9", value: { model.minSwift }, apply: { model.minSwift = $0 }),
                ]
                super.init(style: .insetGrouped)
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError("init(coder:) is unsupported; this app uses no storyboards.")
            }

            override func viewDidLoad() {
                super.viewDidLoad()
                title = "Filters"
                navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissSheet))
                navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Apply", style: .done, target: self, action: #selector(apply))
                tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
            }

            // MARK: Sections: 0 = databases, 1 = filters, 2 = limit

            override func numberOfSections(in _: UITableView) -> Int {
                3
            }

            override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
                switch section {
                case 0: sources.count
                case 1: fields.count
                default: 1
                }
            }

            override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
                switch section {
                case 0: "Databases"
                case 1: "Filters"
                default: "Limit"
                }
            }

            override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
                let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
                cell.accessoryView = nil
                cell.accessoryType = .none
                cell.selectionStyle = .none

                switch indexPath.section {
                case 0:
                    let source = sources[indexPath.row]
                    var content = cell.defaultContentConfiguration()
                    content.text = source.scheme
                    cell.contentConfiguration = content
                    cell.accessoryType = model.sources.contains(source) ? .checkmark : .none
                    cell.selectionStyle = .default
                case 1:
                    let field = fields[indexPath.row]
                    var content = cell.defaultContentConfiguration()
                    content.text = field.title
                    cell.contentConfiguration = content
                    let textField = UITextField(frame: CGRect(x: 0, y: 0, width: 160, height: 32))
                    textField.text = field.value()
                    textField.placeholder = field.placeholder
                    textField.textAlignment = .right
                    textField.autocapitalizationType = .none
                    textField.autocorrectionType = .no
                    textField.clearButtonMode = .whileEditing
                    textField.tag = indexPath.row
                    textField.delegate = self
                    textField.addTarget(self, action: #selector(fieldChanged(_:)), for: .editingChanged)
                    cell.accessoryView = textField
                default:
                    var content = cell.defaultContentConfiguration()
                    content.text = "Limit: \(model.limit)"
                    cell.contentConfiguration = content
                    let stepper = UIStepper()
                    stepper.minimumValue = 1
                    stepper.maximumValue = 100
                    stepper.value = Double(model.limit)
                    stepper.addTarget(self, action: #selector(limitChanged(_:)), for: .valueChanged)
                    cell.accessoryView = stepper
                }
                return cell
            }

            override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
                tableView.deselectRow(at: indexPath, animated: true)
                guard indexPath.section == 0 else { return }
                model.toggle(sources[indexPath.row])
                tableView.reloadRows(at: [indexPath], with: .automatic)
            }

            // MARK: Actions

            @objc private func fieldChanged(_ textField: UITextField) {
                guard textField.tag < fields.count else { return }
                fields[textField.tag].apply(textField.text ?? "")
            }

            @objc private func limitChanged(_ stepper: UIStepper) {
                model.limit = Int(stepper.value)
                tableView.reloadSections(IndexSet(integer: 2), with: .none)
            }

            @objc private func apply() {
                view.endEditing(true)
                model.run()
                dismiss(animated: true)
            }

            @objc private func dismissSheet() {
                dismiss(animated: true)
            }
        }
    }
#endif
