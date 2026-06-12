import AppCore
import AppModels
import PresentationBridge
import SwiftUI

public extension UI {
    struct SwiftUIDocumentReader<VM: Presentation.FrameworkBrowserViewModelProtocol>: View {
        let frameworks: VM
        let doc: Model.DocHit

        @State private var page: Model.DocPage?
        @State private var isLoading = true
        @State private var errorMessage: String?

        public var body: some View {
            Group {
                if isLoading {
                    ProgressView()
                } else if let page {
                    MarkdownReader(markdown: page.markdown, title: page.title)
                        .accessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.reader)
                        .navigationTitle(page.title)
                } else if let error = errorMessage {
                    ContentUnavailableView("Could not load document", systemImage: "exclamationmark.triangle", description: Text(error))
                }
            }
            .task {
                do {
                    page = try await frameworks.readPage(doc.uri)
                } catch {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        }
    }
}
