#!/usr/bin/env swift
// Whole-corpus acceptance gates for XCTemplateDSL. Swift only, per the repo tooling rule.
//
// Every engine change (lexer, parser, decompiler, pack manager, validation) must pass BOTH gates over
// the WHOLE corpus before it is declared done. Sampling is not acceptance.
//
// Gate "roundtrip": decompile each .xctemplate to .xctdsl, compile it back, and compare the full
// recursive folder structure, every file byte for byte, and the TemplateInfo.plist semantically
// (type-strict: a boolean is not an integer). Expected: 100% identical. A case_only result is the
// documented FxPlug / Quartz Composer caveat in Apple's own data, reported by `lint`, and passes.
//
// Gate "check": run the recovering front end on each decompiled .xctdsl. Expected: zero syntax errors
// across the corpus (every shipped template is valid, so any error is a false positive introduced by
// the change). Semantic warnings are allowed (the 9 known case-collision templates).
//
// Usage:
// Gate "ast": parse each decompiled .xctdsl and verify the concrete syntax tree invariants (children
// nested in parents, ordered non-overlapping siblings, root spanning every token). The editor's
// structural view must hold for every shipped template.
//
// Gate "expand": instantiate each decompiled .xctdsl with its default option choices. The expander must
// handle every shipped template without failing; `expanded_empty` (no files materialize, e.g. a base or
// partial template whose content arrives through the lineage) is informational and passes.
//
//   swift scripts/check-corpus.swift [roundtrip|check|ast|expand|all] [--cli PATH] [--corpus DIR ...]

import Foundation

let defaultRoots = [
    "/Volumes/Code/DeveloperExt/private/Templatomat/xcode-templates",
    "/Volumes/Code/DeveloperExt/private/Templatomat/xcode-templates-data",
]

func defaultCLI() -> String {
    let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
    return scriptDir
        .appendingPathComponent("../Packages/.build/release/xctemplate")
        .standardizedFileURL.path
}

// MARK: - Argument parsing

var gate = "all"
var cliPath = defaultCLI()
var roots: [String] = []
var arguments = Array(CommandLine.arguments.dropFirst())
while !arguments.isEmpty {
    let argument = arguments.removeFirst()
    switch argument {
    case "roundtrip", "check", "ast", "expand", "doc", "all": gate = argument
    case "--cli": if !arguments.isEmpty { cliPath = arguments.removeFirst() }
    case "--corpus": if !arguments.isEmpty { roots.append(arguments.removeFirst()) }
    default:
        FileHandle.standardError.write(Data("unknown argument: \(argument)\n".utf8))
        exit(2)
    }
}

if roots.isEmpty { roots = defaultRoots }

guard FileManager.default.isExecutableFile(atPath: cliPath) else {
    print("CLI not found: \(cliPath)  (build it: cd Packages && swift build -c release --product xctemplate)")
    exit(2)
}

// MARK: - Helpers

func run(_ executable: String, _ args: [String]) -> (status: Int32, stdout: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = args
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do { try process.run() } catch { return (127, "") }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
}

func templateDirectories(in roots: [String]) -> [String] {
    var out: [String] = []
    let fm = FileManager.default
    for root in roots {
        guard let enumerator = fm.enumerator(atPath: root) else { continue }
        for case let rel as String in enumerator {
            guard rel.hasSuffix("TemplateInfo.plist"), !rel.contains("__MACOSX") else { continue }
            out.append((root as NSString).appendingPathComponent((rel as NSString).deletingLastPathComponent))
        }
    }
    return out.sorted()
}

/// The full recursive tree (directories suffixed with `/`, files plain), excluding noise.
func tree(of root: String) -> Set<String> {
    var out: Set<String> = []
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(atPath: root) else { return out }
    for case let rel as String in enumerator {
        let name = (rel as NSString).lastPathComponent
        if name == ".DS_Store" || rel == "TemplateInfo.plist" { continue }
        var isDirectory: ObjCBool = false
        let full = (root as NSString).appendingPathComponent(rel)
        guard fm.fileExists(atPath: full, isDirectory: &isDirectory) else { continue }
        out.insert(isDirectory.boolValue ? rel + "/" : rel)
    }
    return out
}

/// Relative path to file contents, excluding noise. Byte-exact comparison basis.
func fileContents(of root: String) -> [String: Data] {
    var out: [String: Data] = [:]
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(atPath: root) else { return out }
    for case let rel as String in enumerator {
        let name = (rel as NSString).lastPathComponent
        if name == ".DS_Store" || rel == "TemplateInfo.plist" { continue }
        let full = (root as NSString).appendingPathComponent(rel)
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: full, isDirectory: &isDirectory), !isDirectory.boolValue else { continue }
        out[rel] = fm.contents(atPath: full) ?? Data()
    }
    return out
}

func loadPlist(_ path: String) -> Any? {
    guard let data = FileManager.default.contents(atPath: path) else { return nil }
    return try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
}

/// Type-strict semantic equality: a Bool is not an Int, key sets match, arrays match in order.
func semanticallyEqual(_ a: Any, _ b: Any) -> Bool {
    if let na = a as? NSNumber, let nb = b as? NSNumber {
        let aIsBool = CFGetTypeID(na) == CFBooleanGetTypeID()
        let bIsBool = CFGetTypeID(nb) == CFBooleanGetTypeID()
        if aIsBool != bIsBool { return false }
        return na == nb
    }
    if let sa = a as? String, let sb = b as? String { return sa == sb }
    if let da = a as? [String: Any], let db = b as? [String: Any] {
        guard Set(da.keys) == Set(db.keys) else { return false }
        for (key, value) in da {
            guard let other = db[key], semanticallyEqual(value, other) else { return false }
        }
        return true
    }
    if let aa = a as? [Any], let ab = b as? [Any] {
        guard aa.count == ab.count else { return false }
        return zip(aa, ab).allSatisfy { semanticallyEqual($0, $1) }
    }
    if let da = a as? Data, let db = b as? Data { return da == db }
    if let da = a as? Date, let db = b as? Date { return da == db }
    return false
}

// MARK: - Gates

enum Outcome: String {
    case identical, caseOnly = "case_only", structureDiff = "structure_diff", contentDiff = "content_diff"
    case plistDiff = "plist_diff", decompileFail = "decompile_fail", compileFail = "compile_fail"
    case ok, okWithSemanticWarnings = "ok_with_semantic_warnings", syntaxErrors = "syntax_errors", error
    case expanded, expandedEmpty = "expanded_empty", expandFail = "expand_fail"
    case documented, undocumented
}

/// Gate "doc": every let key and macro in every decompiled template must have a help entry in the
/// Documentation catalog ("every little possible thing" has a tooltip, proven over the corpus).
func docOutcome(_ source: String) -> Outcome {
    let work = NSTemporaryDirectory() + "gate-" + UUID().uuidString
    defer { try? FileManager.default.removeItem(atPath: work) }
    try? FileManager.default.createDirectory(atPath: work, withIntermediateDirectories: true)
    let dsl = work + "/t.xctdsl"
    _ = run(cliPath, ["decompile", source, dsl])
    guard FileManager.default.fileExists(atPath: dsl) else { return .decompileFail }
    let (status, stdout) = run(cliPath, ["doccheck", dsl])
    if status == 0 { return .documented }
    for line in stdout.split(separator: "\n") where line.hasPrefix("UNDOCUMENTED ") {
        missingNamesQueue.sync { missingNames.insert(String(line.dropFirst(13))) }
    }
    return .undocumented
}

var missingNames: Set<String> = []
let missingNamesQueue = DispatchQueue(label: "missing")

func expandOutcome(_ source: String) -> Outcome {
    let work = NSTemporaryDirectory() + "gate-" + UUID().uuidString
    defer { try? FileManager.default.removeItem(atPath: work) }
    try? FileManager.default.createDirectory(atPath: work, withIntermediateDirectories: true)
    let dsl = work + "/t.xctdsl"
    let out = work + "/expanded"
    _ = run(cliPath, ["decompile", source, dsl])
    guard FileManager.default.fileExists(atPath: dsl) else { return .decompileFail }
    let (status, _) = run(cliPath, ["expand", dsl, out])
    if status != 0 { return .expandFail }
    var produced = 0
    if let enumerator = FileManager.default.enumerator(atPath: out) {
        for case let rel as String in enumerator {
            var isDirectory: ObjCBool = false
            let full = (out as NSString).appendingPathComponent(rel)
            if FileManager.default.fileExists(atPath: full, isDirectory: &isDirectory), !isDirectory.boolValue {
                produced += 1
            }
        }
    }
    return produced > 0 ? .expanded : .expandedEmpty
}

func roundtripOutcome(_ source: String) -> Outcome {
    let work = NSTemporaryDirectory() + "gate-" + UUID().uuidString
    defer { try? FileManager.default.removeItem(atPath: work) }
    try? FileManager.default.createDirectory(atPath: work, withIntermediateDirectories: true)
    let dsl = work + "/t.xctdsl"
    let out = work + "/out"
    _ = run(cliPath, ["decompile", source, dsl])
    guard FileManager.default.fileExists(atPath: dsl) else { return .decompileFail }
    _ = run(cliPath, ["compile", dsl, out])
    let recreated = ((try? FileManager.default.contentsOfDirectory(atPath: out)) ?? [])
        .filter { $0.hasSuffix(".xctemplate") }
    guard let first = recreated.first else { return .compileFail }
    let rec = out + "/" + first
    let sourceTree = tree(of: source)
    let recreatedTree = tree(of: rec)
    if sourceTree != recreatedTree {
        let fold = { (paths: Set<String>) in Set(paths.map { $0.lowercased() }) }
        return fold(sourceTree) == fold(recreatedTree) ? .caseOnly : .structureDiff
    }
    if fileContents(of: source) != fileContents(of: rec) { return .contentDiff }
    guard let original = loadPlist(source + "/TemplateInfo.plist"),
          let roundtripped = loadPlist(rec + "/TemplateInfo.plist"),
          semanticallyEqual(original, roundtripped) else { return .plistDiff }
    return .identical
}

func astOutcome(_ source: String) -> Outcome {
    let work = NSTemporaryDirectory() + "gate-" + UUID().uuidString
    defer { try? FileManager.default.removeItem(atPath: work) }
    try? FileManager.default.createDirectory(atPath: work, withIntermediateDirectories: true)
    let dsl = work + "/t.xctdsl"
    _ = run(cliPath, ["decompile", source, dsl])
    guard FileManager.default.fileExists(atPath: dsl) else { return .decompileFail }
    let (status, stdout) = run(cliPath, ["ast", dsl])
    if status != 0 { return .error }
    return stdout.contains("AST OK") ? .ok : .error
}

func checkOutcome(_ source: String) -> Outcome {
    let work = NSTemporaryDirectory() + "gate-" + UUID().uuidString
    defer { try? FileManager.default.removeItem(atPath: work) }
    try? FileManager.default.createDirectory(atPath: work, withIntermediateDirectories: true)
    let dsl = work + "/t.xctdsl"
    _ = run(cliPath, ["decompile", source, dsl])
    guard FileManager.default.fileExists(atPath: dsl) else { return .decompileFail }
    let (status, stdout) = run(cliPath, ["check", dsl])
    if status != 0 { return .syntaxErrors }
    if stdout.contains(": warning:") { return .okWithSemanticWarnings }
    return .ok
}

func runGate(_ name: String, sources: [String], passing: Set<Outcome>, worker: @escaping (String) -> Outcome) -> Int {
    // Bounded worker pool: each iteration blocks on subprocesses, so unbounded GCD concurrency would
    // explode into hundreds of simultaneous processes and exhaust descriptors. Ten workers pull indices
    // from a shared counter.
    var outcomes = [Outcome](repeating: .error, count: sources.count)
    let resultQueue = DispatchQueue(label: "results")
    let indexQueue = DispatchQueue(label: "index")
    var nextIndex = 0
    let group = DispatchGroup()
    for _ in 0 ..< 10 {
        DispatchQueue.global().async(group: group) {
            while true {
                var index = -1
                indexQueue.sync {
                    if nextIndex < sources.count {
                        index = nextIndex
                        nextIndex += 1
                    }
                }
                if index < 0 { break }
                // Drain Process/Pipe (Objective-C) objects per iteration; without this the file
                // descriptors accumulate in the never-drained autorelease pool and the gate starts
                // failing spuriously around the 5,000th template.
                let outcome = autoreleasepool { worker(sources[index]) }
                resultQueue.sync { outcomes[index] = outcome }
            }
        }
    }
    group.wait()
    var counts: [Outcome: Int] = [:]
    var failures: [(Outcome, String)] = []
    for (index, outcome) in outcomes.enumerated() {
        counts[outcome, default: 0] += 1
        if !passing.contains(outcome), failures.count < 5 {
            failures.append((outcome, sources[index]))
        }
    }
    print("=== GATE \(name): \(sources.count) templates ===")
    for (outcome, count) in counts.sorted(by: { $0.value > $1.value }) {
        let percent = String(format: "%6.2f", 100.0 * Double(count) / Double(sources.count))
        print("  \(String(format: "%6d", count))  (\(percent)%)  \(outcome.rawValue)")
    }
    for (outcome, source) in failures {
        print("  FAIL \(outcome.rawValue): \(source)")
    }
    return outcomes.count(where: { !passing.contains($0) })
}

// MARK: - Main

let sources = templateDirectories(in: roots)
if sources.count < 10000 {
    print("WARNING: only \(sources.count) templates found; the gate expects the WHOLE corpus.")
}

var failureCount = 0
if gate == "roundtrip" || gate == "all" {
    failureCount += runGate("roundtrip", sources: sources, passing: [.identical, .caseOnly], worker: roundtripOutcome)
}

if gate == "check" || gate == "all" {
    failureCount += runGate("check", sources: sources, passing: [.ok, .okWithSemanticWarnings], worker: checkOutcome)
}

if gate == "ast" || gate == "all" {
    failureCount += runGate("ast", sources: sources, passing: [.ok], worker: astOutcome)
}

if gate == "expand" || gate == "all" {
    failureCount += runGate("expand", sources: sources, passing: [.expanded, .expandedEmpty], worker: expandOutcome)
}

if gate == "doc" || gate == "all" {
    failureCount += runGate("doc", sources: sources, passing: [.documented], worker: docOutcome)
    if !missingNames.isEmpty {
        print("  DISTINCT UNDOCUMENTED: \(missingNames.sorted().joined(separator: " "))")
    }
}

print("RESULT: \(failureCount == 0 ? "PASS" : "FAIL (\(failureCount) templates)")")
exit(failureCount == 0 ? 0 : 1)
