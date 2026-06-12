import Foundation

/// The non-throwing recovery accessor's result: the validated document or the errors.
public enum ValidationOutcome<Document> {
    case valid(Document)
    case invalid([ValidationError])
}
