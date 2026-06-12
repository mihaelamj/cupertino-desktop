import AppCore
import AppModels
import PresentationBridge
import SwiftUI

public extension UI {
    struct DocumentsListView<VM: Presentation.FrameworkBrowserViewModelProtocol>: View {
        @Bindable var model: RootModel
        let frameworks: VM
        let framework: Model.Framework

        public var body: some View {
            Group {
                if frameworks.isLoadingDocument {
                    ProgressView()
                } else if let error = frameworks.documentError {
                    ContentUnavailableView("Could not load documents", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    List(frameworks.documents) { doc in
                        NavigationLink {
                            SwiftUIDocumentReader(frameworks: frameworks, doc: doc)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(doc.title)
                                    .font(.headline)
                                if !doc.snippet.isEmpty {
                                    Text(doc.snippet)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .accessibilityIdentifier("document_cell")
                    }
                }
            }
            .navigationTitle(framework.displayName)
            .onAppear {
                model.selectedFrameworkID = framework.id
                frameworks.selectFramework(framework.id)
            }
        }
    }
}
