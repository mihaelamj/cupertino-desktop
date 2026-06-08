import AppCore
import AppModels
import FrameworkBrowserFeature

#if canImport(SwiftUI)
    import SwiftUI

    public extension UI {
        /// The SwiftUI app shell: a two-column navigation split view. The sidebar is the
        /// live framework list from `Feature.FrameworkBrowser.ViewModel`; the detail
        /// renders the selected framework's overview document. The view binds the shared,
        /// framework-agnostic view model and contains no logic. `NavigationSplitView`
        /// adapts across size classes: columns on iPad regular width, a navigation stack
        /// on iPhone compact width (tapping a framework pushes the detail).
        struct RootView: View {
            @Bindable private var model: RootModel
            private let frameworks: Feature.FrameworkBrowser.ViewModel
            /// Keep the sidebar pinned open so iPad shows the list and detail together
            /// in both orientations, rather than the detail-prominent default that slides
            /// the sidebar away as an overlay.
            @State private var columnVisibility = NavigationSplitViewVisibility.all

            public init(model: RootModel, frameworks: Feature.FrameworkBrowser.ViewModel) {
                _model = Bindable(model)
                self.frameworks = frameworks
            }

            public var body: some View {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    sidebar
                        .navigationTitle("Cupertino (SwiftUI)")
                        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 420)
                        .task { frameworks.onAppeared() }
                } detail: {
                    detailColumn
                }
                .navigationSplitViewStyle(.balanced)
                .onChange(of: model.selectedFrameworkID) { _, newID in
                    frameworks.selectFramework(newID)
                }
                .onChange(of: frameworks.frameworks.map(\.id)) { _, ids in
                    autoSelectFirstIfNeeded(ids)
                }
            }

            /// On the Mac (two-column), pre-select the first framework once the list loads so
            /// the detail shows a document instead of the empty state. Skipped on iPhone, where
            /// the compact split would push the detail and hide the list the user wants first.
            private func autoSelectFirstIfNeeded(_ ids: [String]) {
                #if os(macOS)
                    if model.selectedFrameworkID == nil, let first = ids.first {
                        model.selectedFrameworkID = first
                    }
                #endif
            }

            private var sidebar: some View {
                Group {
                    if frameworks.isLoading {
                        ProgressView("Loading frameworks")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let message = frameworks.errorMessage {
                        ContentUnavailableView {
                            Label("Could not load frameworks", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(message)
                        } actions: {
                            Button("Retry") { frameworks.onRetried() }
                        }
                    } else {
                        List(frameworks.frameworks, selection: $model.selectedFrameworkID) { framework in
                            FrameworkRow(framework: framework)
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.sidebar)
            }

            @ViewBuilder private var detailColumn: some View {
                if frameworks.isLoadingDocument {
                    ProgressView()
                } else if let markdown = frameworks.selectedMarkdown {
                    MarkdownReader(markdown: markdown, title: frameworks.selectedDocumentTitle)
                        .accessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.reader)
                        .navigationTitle(frameworks.selectedDocumentTitle ?? "")
                        .environment(\.openURL, OpenURLAction { url in
                            // A tapped in-document link (e.g. "Mentioned in") that resolves
                            // to a doc URI loads in place; anything else opens normally.
                            if let uri = Model.DocURI(url.absoluteString) {
                                frameworks.openDocument(uri)
                                return .handled
                            }
                            return .systemAction
                        })
                } else if let error = frameworks.documentError {
                    ContentUnavailableView(
                        "Could not load document",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error),
                    )
                } else {
                    ContentUnavailableView("Select a framework", systemImage: "doc.text")
                }
            }
        }

        /// One sidebar row: the framework id and its document count.
        private struct FrameworkRow: View {
            let framework: Model.Framework

            var body: some View {
                HStack(spacing: 12) {
                    Text(framework.displayName)
                        .font(.title3)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(framework.documentCount.formatted())
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.vertical, 3)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.row(framework.id))
            }
        }
    }
#endif
