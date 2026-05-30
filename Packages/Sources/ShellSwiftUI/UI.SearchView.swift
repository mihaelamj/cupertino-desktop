import AppCore
import AppModels
import SearchFeature

#if canImport(SwiftUI)
    import SwiftUI

    public extension UI {
        /// The SwiftUI search screen. The results are the main content (a search bar on
        /// top, the result list filling the screen); every other `searchDocs` option
        /// lives behind a Filters sheet so it never buries the results. It binds the
        /// framework-agnostic `Feature.Search.ViewModel`.
        struct SearchView: View {
            @Bindable private var model: Feature.Search.ViewModel
            @State private var showingFilters = false

            public init(model: Feature.Search.ViewModel) {
                _model = Bindable(model)
            }

            public var body: some View {
                NavigationStack {
                    content
                        .navigationTitle("Search")
                        .searchable(text: $model.text, prompt: "Search documentation")
                        .onSubmit(of: .search) { model.run() }
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button { showingFilters = true } label: {
                                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                                }
                            }
                        }
                        .sheet(isPresented: $showingFilters) { filters }
                        .task { if !model.hasRun { model.run() } }
                }
            }

            @ViewBuilder private var content: some View {
                if model.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = model.errorMessage {
                    ContentUnavailableView("Could not search", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if model.hasRun, model.results.isEmpty {
                    ContentUnavailableView("No matches", systemImage: "magnifyingglass", description: Text("Adjust the query or the filters."))
                } else {
                    List(model.results) { hit in
                        ResultRow(hit: hit)
                    }
                    .overlay(alignment: .top) {
                        Text("\(model.results.count) results")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(6)
                    }
                }
            }

            /// Every remaining option, behind the Filters button.
            private var filters: some View {
                NavigationStack {
                    Form {
                        Section("Databases") {
                            ForEach(Model.Source.allCases, id: \.self) { source in
                                Toggle(source.scheme, isOn: Binding(
                                    get: { model.sources.contains(source) },
                                    set: { _ in model.toggle(source) },
                                ))
                            }
                        }
                        Section("Filters") {
                            TextField("Framework (e.g. SwiftUI)", text: $model.framework)
                            TextField("min iOS (e.g. 17.0)", text: $model.minIOS)
                            TextField("min macOS (e.g. 14.0)", text: $model.minMacOS)
                            TextField("min Swift (e.g. 5.9)", text: $model.minSwift)
                        }
                        Section("Limit") {
                            Stepper("Limit: \(model.limit)", value: $model.limit, in: 1 ... 100)
                        }
                    }
                    .navigationTitle("Filters")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Apply") {
                                model.run()
                                showingFilters = false
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showingFilters = false }
                        }
                    }
                }
            }
        }

        /// One search result: title, the source database it came from, the framework,
        /// and a snippet.
        private struct ResultRow: View {
            let hit: Model.DocHit

            var body: some View {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(hit.title)
                            .font(.headline)
                        Spacer()
                        Text(hit.source.scheme)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let framework = hit.framework {
                        Text(framework)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if !hit.snippet.isEmpty {
                        Text(hit.snippet)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
#endif
