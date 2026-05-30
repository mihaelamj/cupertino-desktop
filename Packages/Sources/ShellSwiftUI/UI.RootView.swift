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
                        .task { frameworks.onAppeared() }
                } detail: {
                    detailColumn
                }
                .navigationSplitViewStyle(.balanced)
                .onChange(of: model.selectedFrameworkID) { _, newID in
                    frameworks.selectFramework(newID)
                }
            }

            @ViewBuilder private var sidebar: some View {
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

            @ViewBuilder private var detailColumn: some View {
                if frameworks.isLoadingDocument {
                    ProgressView()
                } else if let markdown = frameworks.selectedMarkdown {
                    ScrollView {
                        Text(Self.rendered(markdown))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding()
                    }
                    .navigationTitle(frameworks.selectedDocumentTitle ?? "")
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

            /// Render markdown for display, preserving line breaks and inline styling.
            /// Block syntax (headings, fenced code) stays literal, which is fine for the
            /// current mock content; a full renderer is a later milestone.
            private static func rendered(_ markdown: String) -> AttributedString {
                let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
            }
        }

        /// One sidebar row: the framework id and its document count.
        private struct FrameworkRow: View {
            let framework: Model.Framework

            var body: some View {
                HStack {
                    Text(framework.name)
                    Spacer()
                    Text(framework.documentCount.formatted())
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }
#endif
