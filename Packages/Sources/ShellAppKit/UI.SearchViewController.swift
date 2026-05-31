import AppCore
import AppModels
import CodeHighlighting
import MarkdownRendering
import SearchFeature

#if canImport(AppKit)
    import AppKit

    public extension UI {
        /// Build the AppKit search screen as a base view controller, so an app target can
        /// drop it into a tab without seeing the concrete class (mirrors how the framework
        /// browser is reached through `RootExperience`). It binds the shared, framework-
        /// agnostic `Feature.Search.ViewModel`.
        @MainActor
        static func makeSearch(model: Feature.Search.ViewModel) -> NSViewController {
            SearchViewController(model: model)
        }
    }

    extension UI {
        /// The AppKit search screen, the counterpart of the SwiftUI `UI.SearchView` and
        /// the UIKit `UI.SearchViewController`: a search field with a Docs/Everything
        /// scope and a Filters popover, a results list, and a reader pane that renders the
        /// selected document's full markdown. It binds the shared, framework-agnostic
        /// `Feature.Search.ViewModel`, the exact same view model the other two search
        /// screens use, and holds no logic. State changes are picked up with
        /// `withObservationTracking`; live search is debounced through the view model.
        @MainActor
        final class SearchViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, NSTextViewDelegate {
            private let model: Feature.Search.ViewModel
            private let searchField = NSSearchField()
            private let scope = NSSegmentedControl(labels: ["Docs", "Everything"], trackingMode: .selectOne, target: nil, action: nil)
            private let filtersButton = NSButton()
            private let textSizeControls = NSStackView()
            private let tableView = NSTableView()
            private let resultsScroll = NSScrollView()
            private let readerView = NSTextView()
            private let readerScroll = NSScrollView()
            private let statusLabel = NSTextField(labelWithString: "")
            private let popover = NSPopover()

            /// A flattened snapshot of the result list: section headers plus item rows.
            private enum Row {
                case header(String)
                case doc(Model.DocHit)
                case sample(Model.SampleProject)
                case package(Model.PackageHit)
            }

            private var rows: [Row] = []

            init(model: Feature.Search.ViewModel) {
                self.model = model
                super.init(nibName: nil, bundle: nil)
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError("init(coder:) is unsupported; this app uses no XIBs.")
            }

            override func loadView() {
                let container = NSView()
                let topBar = makeTopBar()
                let split = makeSplit()
                container.addSubview(topBar)
                container.addSubview(split)

                statusLabel.textColor = .secondaryLabelColor
                statusLabel.alignment = .center
                statusLabel.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(statusLabel)

                NSLayoutConstraint.activate([
                    topBar.topAnchor.constraint(equalTo: container.topAnchor),
                    topBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    topBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    split.topAnchor.constraint(equalTo: topBar.bottomAnchor),
                    split.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    split.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    split.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    resultsScroll.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
                    resultsScroll.widthAnchor.constraint(lessThanOrEqualToConstant: 460),
                    // The reader pane must keep a width, otherwise the results list takes the
                    // whole split and the selected document has nowhere to render.
                    readerScroll.widthAnchor.constraint(greaterThanOrEqualToConstant: 360),
                    statusLabel.centerXAnchor.constraint(equalTo: resultsScroll.centerXAnchor),
                    statusLabel.centerYAnchor.constraint(equalTo: resultsScroll.centerYAnchor),
                    statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 16),
                ])
                view = container
            }

            private func makeTopBar() -> NSStackView {
                searchField.placeholderString = "Search documentation"
                searchField.delegate = self
                searchField.target = self
                searchField.action = #selector(submit)

                scope.selectedSegment = 0
                scope.target = self
                scope.action = #selector(scopeChanged)

                filtersButton.title = "Filters"
                filtersButton.image = NSImage(systemSymbolName: "line.3.horizontal.decrease.circle", accessibilityDescription: "Filters")
                filtersButton.imagePosition = .imageLeading
                filtersButton.bezelStyle = .rounded
                filtersButton.target = self
                filtersButton.action = #selector(showFilters)

                let smaller = sizeButton("textformat.size.smaller", action: #selector(textSmaller), tip: "Smaller text")
                let larger = sizeButton("textformat.size.larger", action: #selector(textLarger), tip: "Larger text")
                textSizeControls.orientation = .horizontal
                textSizeControls.spacing = 4
                textSizeControls.addArrangedSubview(smaller)
                textSizeControls.addArrangedSubview(larger)

                let topBar = NSStackView(views: [searchField, scope, filtersButton, textSizeControls])
                topBar.orientation = .horizontal
                topBar.spacing = 8
                topBar.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
                topBar.translatesAutoresizingMaskIntoConstraints = false
                searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
                return topBar
            }

            private func makeSplit() -> NSSplitView {
                let column = NSTableColumn(identifier: .init("result"))
                column.resizingMask = .autoresizingMask
                tableView.addTableColumn(column)
                tableView.headerView = nil
                tableView.style = .inset
                tableView.dataSource = self
                tableView.delegate = self
                tableView.rowHeight = 48
                resultsScroll.documentView = tableView
                resultsScroll.hasVerticalScroller = true

                readerView.isEditable = false
                readerView.delegate = self
                readerView.drawsBackground = false
                readerView.textContainerInset = NSSize(width: 16, height: 16)
                readerView.font = .systemFont(ofSize: NSFont.systemFontSize)
                readerScroll.documentView = readerView
                readerScroll.hasVerticalScroller = true
                readerScroll.drawsBackground = false

                let split = NSSplitView()
                split.isVertical = true
                split.dividerStyle = .thin
                split.translatesAutoresizingMaskIntoConstraints = false
                split.addArrangedSubview(resultsScroll)
                split.addArrangedSubview(readerScroll)
                return split
            }

            override func viewDidLoad() {
                super.viewDidLoad()
                track()
                if !model.hasRun { model.run() }
                render()
            }

            // MARK: Observation

            private func track() {
                withObservationTracking {
                    _ = model.state
                } onChange: { [weak self] in
                    Task { @MainActor in
                        guard let self else { return }
                        self.render()
                        self.track()
                    }
                }
            }

            private func render() {
                rows = Self.makeRows(model)
                let hasResults = rows.contains { if case .header = $0 { false } else { true } }
                statusLabel.isHidden = hasResults
                statusLabel.stringValue = statusText
                tableView.reloadData()
            }

            private var statusText: String {
                if model.isLoading { return "Searching..." }
                if let error = model.errorMessage { return error }
                if model.hasRun { return "No matches.\nAdjust the query or the filters." }
                return "Search documentation"
            }

            private static func makeRows(_ model: Feature.Search.ViewModel) -> [Row] {
                switch model.scope {
                case .docs:
                    return model.results.map(Row.doc)
                case .everything:
                    guard let unified = model.unified else { return [] }
                    var built: [Row] = []
                    if !unified.docs.isEmpty {
                        built.append(.header("Docs (\(unified.docs.count))"))
                        built.append(contentsOf: unified.docs.map(Row.doc))
                    }
                    if !unified.samples.projects.isEmpty {
                        built.append(.header("Samples (\(unified.samples.projects.count))"))
                        built.append(contentsOf: unified.samples.projects.map(Row.sample))
                    }
                    if !unified.packages.isEmpty {
                        built.append(.header("Packages (\(unified.packages.count))"))
                        built.append(contentsOf: unified.packages.map(Row.package))
                    }
                    return built
                }
            }

            // MARK: Actions

            @objc private func submit() {
                model.text = searchField.stringValue
                model.run()
            }

            @objc private func scopeChanged() {
                model.scope = scope.selectedSegment == 1 ? .everything : .docs
                model.run()
            }

            @objc private func showFilters() {
                let filters = SearchFiltersViewController(model: model) { [weak self] in
                    self?.popover.close()
                    self?.model.run()
                }
                popover.behavior = .transient
                popover.contentViewController = filters
                popover.show(relativeTo: filtersButton.bounds, of: filtersButton, preferredEdge: .maxY)
            }

            func controlTextDidChange(_: Notification) {
                model.text = searchField.stringValue
                model.runDebounced()
            }

            // MARK: Reader

            private func openSelection() {
                let selected = tableView.selectedRow
                guard selected >= 0, selected < rows.count else { return }
                switch rows[selected] {
                case let .doc(hit):
                    read(hit.uri)
                case let .package(hit):
                    if let uri = Model.DocURI(hit.id) { read(uri) } else { readerView.string = hit.snippet }
                case let .sample(project):
                    readerView.string = project.summary.isEmpty ? project.title : project.summary
                case .header:
                    break
                }
            }

            private func read(_ uri: Model.DocURI) {
                readerView.string = "Loading..."
                Task { @MainActor in
                    do {
                        let page = try await model.readPage(uri)
                        let base = Markdown.Theme().basePointSize
                        readerView.textStorage?.setAttributedString(Markdown.attributed(
                            page: page,
                            highlighter: Highlight.Splash(),
                            theme: Markdown.Theme(basePointSize: base * Model.ReaderTextSize.current),
                        ))
                    } catch {
                        readerView.string = "Could not open the document."
                    }
                }
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

            @objc private func textLarger() {
                Model.ReaderTextSize.larger()
                openSelection()
            }

            @objc private func textSmaller() {
                Model.ReaderTextSize.smaller()
                openSelection()
            }

            /// A clicked in-document link loads that document in the reader pane in place.
            func textView(_: NSTextView, clickedOnLink link: Any, at _: Int) -> Bool {
                let urlString = (link as? URL)?.absoluteString ?? (link as? String)
                guard let urlString, let uri = Model.DocURI(urlString) else { return false }
                read(uri)
                return true
            }
        }
    }

    /// The table data source/delegate, in an extension so the controller's own body stays
    /// within the type-length budget.
    extension UI.SearchViewController {
        func numberOfRows(in _: NSTableView) -> Int {
            rows.count
        }

        func tableView(_: NSTableView, isGroupRow row: Int) -> Bool {
            if case .header = rows[row] { return true }
            return false
        }

        func tableView(_: NSTableView, shouldSelectRow row: Int) -> Bool {
            if case .header = rows[row] { return false }
            return true
        }

        func tableView(_: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
            switch rows[row] {
            case let .header(title):
                Self.label(title, secondary: nil, bold: true)
            case let .doc(hit):
                Self.label(hit.title, secondary: [hit.framework, hit.snippet.isEmpty ? nil : hit.snippet].compactMap(\.self).joined(separator: " : "))
            case let .sample(project):
                Self.label(project.title, secondary: project.summary)
            case let .package(hit):
                Self.label(hit.title, secondary: "\(hit.owner)/\(hit.repo)")
            }
        }

        func tableViewSelectionDidChange(_: Notification) {
            openSelection()
        }

        fileprivate static func label(_ title: String, secondary: String?, bold: Bool = false) -> NSView {
            let titleLabel = NSTextField(labelWithString: title)
            titleLabel.font = bold
                ? .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
                : .systemFont(ofSize: NSFont.systemFontSize)
            titleLabel.lineBreakMode = .byTruncatingTail
            let stack = NSStackView(views: [titleLabel])
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 2
            if let secondary, !secondary.isEmpty {
                let secondaryLabel = NSTextField(labelWithString: secondary)
                secondaryLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
                secondaryLabel.textColor = .secondaryLabelColor
                secondaryLabel.lineBreakMode = .byTruncatingTail
                stack.addArrangedSubview(secondaryLabel)
            }
            return stack
        }
    }
#endif
