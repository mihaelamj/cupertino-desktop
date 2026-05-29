import AppKit

// AppKit without a storyboard needs an explicit entry point, so this app uses
// main.swift rather than @main (docs/rules/package-structure.md).
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
