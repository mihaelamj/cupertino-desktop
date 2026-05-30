/// Errors thrown by `StepRegistry.execute`.
public enum StepRegistryError: Error, CustomStringConvertible {
    /// No handler for `verb:target`: always a scenario/registry mismatch, never a UI fault.
    case unknownStep(key: String)
    /// The step is known but the UI action failed (element missing, assertion, timeout).
    case stepFailed(key: String, reason: String)

    public var description: String {
        switch self {
        case let .unknownStep(key):
            "FlowSpec: unknown step `\(key)`: no handler registered."
        case let .stepFailed(key, reason):
            "FlowSpec: step `\(key)` failed: \(reason)"
        }
    }
}
