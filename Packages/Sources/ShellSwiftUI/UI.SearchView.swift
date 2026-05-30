import AppCore
import AppModels
import SearchFeature

#if canImport(SwiftUI)
    import SwiftUI

    public extension UI {
        /// The SwiftUI search screen. Results are the main content (a search bar on top,
        /// a Docs/Everything scope, the result list filling the screen); every other
        /// `searchDocs` option lives behind a Filters sheet so it never buries the
        /// results. The "everything" scope shows a unified, source-bucketed result (docs,
        /// samples, packages). Binds the framework-agnostic `Feature.Search.ViewModel`.
        struct SearchView: View {
            @Bindable private var model: Feature.Search.ViewModel
            @State private var showingFilters = false

            public init(model: Feature.Search.ViewModel) {
                _model = Bindable(model)
            }

            public var body: some View {
                NavigationStack {
                    VStack(spacing: 0) {
                        Picker("Scope", selection: $model.scope) {
                            Text("Docs").tag(Feature.Search.ViewModel.Scope.docs)
                            Text("Everything").tag(Feature.Search.ViewModel.Scope.everything)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        content
                    }
                    .navigationTitle("Search")
                    .searchable(text: $model.text, prompt: "Search documentation")
                    .onChange(of: model.text) { _, _ in model.runDebounced() }
                    .onSubmit(of: .search) { model.run() }
                    .onChange(of: model.scope) { _, _ in model.run() }
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button { showingFilters = true } label: {
                                Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                            }
                        }
                    }
                    .sheet(isPresented: $showingFilters) { filters }
                    .navigationDestination(for: Model.DocHit.self) { hit in
                        DocumentReaderView(model: model, hit: hit)
                    }
                    .task { if !model.hasRun { model.run() } }
                }
            }

            @ViewBuilder private var content: some View {
                if model.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = model.errorMessage {
                    ContentUnavailableView("Could not search", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    switch model.scope {
                    case .docs: docsList
                    case .everything: everythingList
                    }
                }
            }

            @ViewBuilder private var docsList: some View {
                if model.hasRun, model.results.isEmpty {
                    ContentUnavailableView("No matches", systemImage: "magnifyingglass", description: Text("Adjust the query or the filters."))
                } else {
                    List(model.results) { hit in
                        NavigationLink(value: hit) { DocRow(hit: hit) }
                    }
                }
            }

            @ViewBuilder private var everythingList: some View {
                if let unified = model.unified {
                    List {
                        if !unified.docs.isEmpty {
                            Section("Docs (\(unified.docs.count))") {
                                ForEach(unified.docs) { hit in
                                    NavigationLink(value: hit) { DocRow(hit: hit) }
                                }
                            }
                        }
                        if !unified.samples.projects.isEmpty {
                            Section("Samples (\(unified.samples.projects.count))") {
                                ForEach(unified.samples.projects) { SampleRow(project: $0) }
                            }
                        }
                        if !unified.packages.isEmpty {
                            Section("Packages (\(unified.packages.count))") {
                                ForEach(unified.packages) { PackageRow(hit: $0) }
                            }
                        }
                        if unified.docs.isEmpty, unified.samples.projects.isEmpty, unified.packages.isEmpty {
                            ContentUnavailableView("No matches", systemImage: "magnifyingglass")
                        }
                    }
                } else {
                    Color.clear
                }
            }

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

        private struct DocRow: View {
            let hit: Model.DocHit
            var body: some View {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(hit.title).font(.headline)
                        Spacer()
                        Text(hit.source.scheme).font(.caption).foregroundStyle(.secondary)
                    }
                    if let framework = hit.framework {
                        Text(framework).font(.caption2).foregroundStyle(.tertiary)
                    }
                    if !hit.snippet.isEmpty {
                        Text(hit.snippet).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .padding(.vertical, 2)
            }
        }

        private struct SampleRow: View {
            let project: Model.SampleProject
            var body: some View {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title).font(.headline)
                    if !project.summary.isEmpty {
                        Text(project.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .padding(.vertical, 2)
            }
        }

        private struct PackageRow: View {
            let hit: Model.PackageHit
            var body: some View {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hit.title).font(.headline)
                    Text("\(hit.owner)/\(hit.repo)").font(.caption2).foregroundStyle(.tertiary)
                    if !hit.snippet.isEmpty {
                        Text(hit.snippet).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .padding(.vertical, 2)
            }
        }

        /// The page opened when a result is tapped: reads the document by URI and renders
        /// its markdown. Replaced by the full document reader in a later milestone.
        private struct DocumentReaderView: View {
            let model: Feature.Search.ViewModel
            let hit: Model.DocHit
            @State private var page: Model.DocPage?
            @State private var failed = false

            var body: some View {
                Group {
                    if let page {
                        ScrollView {
                            Text(Self.rendered(page.markdown))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .padding()
                        }
                    } else if failed {
                        ContentUnavailableView("Could not open the document", systemImage: "exclamationmark.triangle")
                    } else {
                        ProgressView()
                    }
                }
                .navigationTitle(hit.title)
                .task {
                    do { page = try await model.readPage(hit.uri) } catch { failed = true }
                }
            }

            private static func rendered(_ markdown: String) -> AttributedString {
                let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
            }
        }
    }
#endif
