import AppCore
import AppModels
import BackendAPI
import Foundation
import Observation
import PresentationBridge

public extension Feature.FrameworkBrowser.ViewModel {
    func selectDocument(_ uri: Model.DocURI) {
        NSLog("VM SELECT DOCUMENT: \(uri.rawValue)")
        if case let .loaded(page) = documentState, page.uri == uri {
            NSLog("VM SELECT DOCUMENT: already loaded")
            return
        }
        let previous = docTask
        previous?.cancel()
        documentState = .loading
        docTask = Task { [weak self] in
            NSLog("VM SELECT DOCUMENT: task started")
            await previous?.value
            guard !Task.isCancelled else {
                NSLog("VM SELECT DOCUMENT: task cancelled after previous value")
                return
            }
            NSLog("VM SELECT DOCUMENT: calling readDocument")
            await self?.readDocument(uri)
        }
    }

    func readPage(_ uri: Model.DocURI) async throws -> Model.DocPage {
        try await backend.readDocument(uri)
    }

    /// Open an arbitrary document by URI in the detail column, replacing the current
    /// one. Used when a link inside a rendered document is tapped (e.g. a "Mentioned
    /// in" entry), so the reader can follow it without going through the sidebar.
    func openDocument(_ uri: Model.DocURI) {
        if case let .loaded(page) = documentState, page.uri == uri {
            return
        }
        let previous = docTask
        previous?.cancel()
        documentState = .loading
        // Same serialization as selectFramework: no overlapping reads on the shared client.
        docTask = Task { [weak self] in
            await previous?.value
            guard !Task.isCancelled else { return }
            await self?.readDocument(uri)
        }
    }

    /// Test hook: await the in-flight document load so tests are deterministic without
    /// polling. Internal, used only by the feature's tests.
    func awaitDocumentLoad() async {
        await docTask?.value
    }

    /// Read a document by URI into the detail. Internal so a test can drive it.
    func readDocument(_ uri: Model.DocURI) async {
        do {
            NSLog("VM READ DOCUMENT: backend read start: \(uri.rawValue)")
            let page = try await backend.readDocument(uri)
            if Task.isCancelled {
                NSLog("VM READ DOCUMENT: task cancelled after backend read")
                return
            }
            NSLog("VM READ DOCUMENT: loaded successfully: \(page.title)")
            documentState = .loaded(page)
        } catch {
            if Task.isCancelled {
                NSLog("VM READ DOCUMENT: task cancelled on error")
                return
            }
            NSLog("VM READ DOCUMENT: failed: \(error.localizedDescription)")
            documentState = .failed(error.localizedDescription)
        }
    }

    /// Search and load all documents in the selected framework. Scoped to it.
    func loadDocuments(framework id: String) async {
        do {
            let currentSource = selectedSource ?? .appleDocs
            let hits: [Model.DocHit]

            if selectedSource == nil {
                let sources: Set<Model.Source> = [.appleDocs]
                hits = try await backend.searchDocs(Model.DocsQuery(text: id, sources: sources, framework: id, limit: 100_000))
            } else {
                let items = try await backend.listSourceHierarchy(source: currentSource, level: 2, parent: id)
                hits = items.compactMap { item in
                    guard let uri = Model.DocURI(item.id) ?? Model.DocURI("\(currentSource.scheme)://\(item.id)") else {
                        return nil
                    }
                    return Model.DocHit(
                        id: item.id,
                        uri: uri,
                        source: currentSource,
                        title: item.title,
                        framework: id,
                        snippet: item.description ?? "",
                        score: 0.0,
                    )
                }
            }

            if Task.isCancelled { return }
            documents = hits
            if let first = hits.first {
                await readDocument(first.uri)
            } else {
                documentState = .empty
            }
        } catch {
            if Task.isCancelled { return }
            documents = []
            documentState = .failed(error.localizedDescription)
        }
    }
}
