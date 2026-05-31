import FlowSpec
import Foundation

// Renders an Apple-styled HTML report from scenario results.
// Usage: FlowSpecReportTool <results.json> <output.html>
// `results.json` is a JSON array of `ScenarioResult`, produced from an xcodebuild test run.

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: FlowSpecReportTool <results.json> <output.html>\n".utf8))
    exit(2)
}

do {
    let data = try Data(contentsOf: URL(fileURLWithPath: arguments[1]))
    let results = try JSONDecoder().decode([ScenarioResult].self, from: data)
    let html = ScenarioReport(title: "Cupertino Desktop UI Test Report", results: results).html()
    try html.write(toFile: arguments[2], atomically: true, encoding: .utf8)
    print("Wrote \(arguments[2]) (\(results.filter(\.passed).count)/\(results.count) scenarios passed)")
} catch {
    FileHandle.standardError.write(Data("FlowSpecReportTool failed: \(error)\n".utf8))
    exit(1)
}
