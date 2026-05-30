import AppCore
import AppModels
import SearchFeature

#if canImport(SwiftUI)
    import SwiftUI

    public extension UI {
        /// The SwiftUI search screen: a form exposing every `searchDocs` option the
        /// backend can answer (text, the source databases, framework, per-platform
        /// minimums, and a result limit), with the results listed below. It binds the
        /// framework-agnostic `Feature.Search.ViewModel`, so the AppKit and UIKit shells
        /// can present the same options over the same view model.
        struct SearchView: View {
            @Bindable private var model: Feature.Search.ViewModel

            public init(model: Feature.Search.ViewModel) {
                _model = Bindable(model)
            }

            public var body: some View {
                NavigationStack {
                    Form {
                        Section("Query") {
                            TextField("Search text", text: $model.text)
                                .onSubmit { model.run() }
                            Stepper("Limit: \(model.limit)", value: $model.limit, in: 1 ... 100)
                        }

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

                        Section {
                            Button("Run search") { model.run() }
                        }

                        results
                    }
                    .navigationTitle("Search")
                    .task { if !model.hasRun { model.run() } }
                }
            }

            @ViewBuilder private var results: some View {
                if model.isLoading {
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                } else if let error = model.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                } else if model.hasRun {
                    Section("Results (\(model.results.count))") {
                        if model.results.isEmpty {
                            Text("No matches for these options.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(model.results) { hit in
                                ResultRow(hit: hit)
                            }
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
