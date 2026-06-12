import AppModels
import Foundation
import PresentationBridge

let args = CommandLine.arguments
guard args.count > 1 else {
    print("Usage: swift run clil <file.clil | file.cdsl | file.cll>")
    exit(1)
}

let filePath = args[1]
let fileURL = URL(fileURLWithPath: filePath)

do {
    let script = try String(contentsOf: fileURL, encoding: .utf8)
    let frameworksVM = CLIFFrameworkBrowserViewModel()
    let searchVM = CLISearchViewModel()
    let simulator = Presentation.CLILSimulator(frameworks: frameworksVM, search: searchVM)

    print("Running CLIL simulation script '\(filePath)'...")

    if filePath.hasSuffix(".cdsl") {
        try await simulator.runCDSL(script)
    } else if filePath.hasSuffix(".cll") {
        try await simulator.runCLL(script)
    } else {
        try await simulator.run(script)
    }

    print("\u{001B}[32mSUCCESS: All assertions passed successfully!\u{001B}[0m")
} catch {
    print("\u{001B}[31mFAILURE: \(error)\u{001B}[0m")
    exit(1)
}
