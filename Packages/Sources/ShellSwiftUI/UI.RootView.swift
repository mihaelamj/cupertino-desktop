import AppCore
import AppModels
import FrameworkBrowserFeature

#if canImport(SwiftUI)
    import SwiftUI

    public extension UI {
        /// The SwiftUI app shell: a three-column navigation split view. The sidebar is
        /// the live framework list from `Feature.FrameworkBrowser.ViewModel`; the
        /// content and detail columns are still placeholders (later milestones). The
        /// view binds the shared, framework-agnostic view model and contains no logic.
        struct RootView: View {
            @Bindable private var model: RootModel
            private let frameworks: Feature.FrameworkBrowser.ViewModel

            public init(model: RootModel, frameworks: Feature.FrameworkBrowser.ViewModel) {
                _model = Bindable(model)
                self.frameworks = frameworks
            }

            public var body: some View {
                NavigationSplitView {
                    sidebar
                        .navigationTitle("Cupertino")
                        .task { frameworks.onAppeared() }
                } content: {
                    ContentUnavailableView(
                        "Select a framework",
                        systemImage: "books.vertical",
                    )
                } detail: {
                    if let id = model.selectedFrameworkID {
                        Text(id)
                    } else {
                        ContentUnavailableView(
                            "Select a document",
                            systemImage: "doc.text",
                        )
                    }
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
