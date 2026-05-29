/// The UI seam shared by both framework implementations. This anchor and the
/// framework-agnostic view models live in Core; the SwiftUI and AppKit packages
/// each extend it with a same-shaped `RootExperience` protocol and their native
/// root, so both are consumed identically.
public enum UI {}
