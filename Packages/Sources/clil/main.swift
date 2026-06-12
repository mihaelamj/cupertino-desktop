import AppCore
import AppModels
import BackendAPI
import Foundation
@testable import FrameworkBrowserFeature
import MacBackendImpl
import PresentationBridge
import SearchFeature

let args = CommandLine.arguments
guard args.count > 1 else {
    print("Usage: swift run clil <file.clil | file.cdsl | file.cll>")
    exit(1)
}

let filePath = args[1]
let fileURL = URL(fileURLWithPath: filePath)

do {
    let script = try String(contentsOf: fileURL, encoding: .utf8)

    let frameworksVM: any Presentation.FrameworkBrowserViewModelProtocol
    let searchVM: any Presentation.SearchViewModelProtocol

    let isIntegration = ProcessInfo.processInfo.environment["CUPERTINO_INTEGRATION"] == "1"
    var liveBackend: (any Backend.Documentation)? = nil

    if isIntegration {
        print("Initializing production view models and macOS subprocess backend...")
        let backend = MacBackend.live()
        try await backend.connect()
        print("Connected to cupertino subprocess successfully.")
        liveBackend = backend

        let fVM = Feature.FrameworkBrowser.ViewModel(backend: backend)
        let sVM = Feature.Search.ViewModel(backend: backend)

        // Start the initial load of sources and frameworks and await it
        fVM.onAppeared()
        if let loadTask = fVM.loadTask {
            _ = await loadTask.value
        }

        frameworksVM = fVM
        searchVM = sVM
    } else {
        frameworksVM = CLIFFrameworkBrowserViewModel()
        searchVM = CLISearchViewModel()
    }

    let simulator = Presentation.CLILSimulator(frameworks: frameworksVM, search: searchVM)

    if isIntegration, let fVM = frameworksVM as? Feature.FrameworkBrowser.ViewModel {
        simulator.onStepExecuted = { @MainActor in
            if let loadTask = fVM.loadTask {
                _ = await loadTask.value
            }
            if let hierarchyTask = fVM.hierarchyTask {
                _ = await hierarchyTask.value
            }
            if fVM.skipAwaitingDocTask {
                fVM.skipAwaitingDocTask = false
            } else if let docTask = fVM.docTask {
                _ = await docTask.value
            }
            await Task.yield()
        }
    }

    print("Running CLIL simulation script '\(filePath)'...")

    if filePath.hasSuffix(".cdsl") {
        try await simulator.runCDSL(script)
    } else if filePath.hasSuffix(".cll") {
        try await simulator.runCLL(script)
    } else {
        try await simulator.run(script)
    }

    // If in integration mode, print out what we actually loaded on each level to verify!
    if isIntegration {
        print("\n=== Live Database Hierarchy Verification Report ===")

        // 1. Sources
        let sources = try await frameworksVM.listSources()
        print("1. Available Sources (\(sources.count)):")
        for src in sources {
            print("  - \(src.rawValue) (display: \(src.displayName), scheme: \(src.scheme))")
        }

        // 2. Level 1: Frameworks loaded in the view model
        print("\n2. Level 1 (Frameworks loaded for \(frameworksVM.selectedSource?.displayName ?? "none")):")
        let loadedFrameworks = frameworksVM.frameworks
        print("   Total frameworks loaded: \(loadedFrameworks.count)")
        for fw in loadedFrameworks.prefix(5) {
            print("     - \(fw.name) (id: \(fw.id), \(fw.documentCount) documents)")
        }
        if loadedFrameworks.count > 5 {
            print("     ... and \(loadedFrameworks.count - 5) more")
        }

        // 3. Level 2: Documents loaded under selected framework
        print("\n3. Level 2 (Documents loaded for framework \(frameworksVM.selectedFramework?.name ?? "none")):")
        let loadedDocs = frameworksVM.documents
        print("   Total documents loaded: \(loadedDocs.count)")
        for doc in loadedDocs.prefix(5) {
            print("     - \(doc.title) (uri: \(doc.uri.rawValue))")
        }
        if loadedDocs.count > 5 {
            print("     ... and \(loadedDocs.count - 5) more")
        }

        // 4. Level 3: Selected Document content
        print("\n4. Level 3 (Document content loaded):")
        if let title = frameworksVM.selectedDocumentTitle {
            print("   Active Document Title: \(title)")
            if let markdown = frameworksVM.selectedMarkdown {
                print("   Content Preview (first 150 chars):")
                let preview = String(markdown.prefix(150)).replacingOccurrences(of: "\n", with: " ")
                print("     \"\(preview)...\"")
            }
        } else {
            print("   No active document.")
        }
        print("===================================================\n")

        if let liveBackend {
            await liveBackend.disconnect()
        }
    }

    print("\u{001B}[32mSUCCESS: All assertions passed successfully!\u{001B}[0m")
} catch {
    print("\u{001B}[31mFAILURE: \(error)\u{001B}[0m")
    exit(1)
}
