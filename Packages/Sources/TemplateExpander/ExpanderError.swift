import Foundation

/// A failure during template expansion that has no recovery: silently skipping the file would make
/// the output an incomplete bundle, so the expander throws instead of printing and continuing.
public enum ExpanderError: Error, CustomStringConvertible {
    case undecodableBinaryContent(path: String)
    /// A resolved output path landed outside the output directory (a `..` or absolute segment
    /// arrived through a node path or a choice value). Expansion writes ONLY under its output
    /// directory; anything else is refused, never silently written elsewhere.
    case pathOutsideOutput(path: String)

    public var description: String {
        switch self {
        case let .undecodableBinaryContent(path):
            "binary content for \(path) is not valid base64"
        case let .pathOutsideOutput(path):
            "resolved path \(path) is outside the output directory"
        }
    }
}
