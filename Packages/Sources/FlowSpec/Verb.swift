/// Closed verb vocabulary for FlowSpec scenarios. Intentionally tiny: adding a case is a
/// coordinated change across the schema, this enum, and every `StepRegistry`.
public enum Verb: String, Codable, Sendable, CaseIterable {
    /// Navigate to a screen / route. `target` is a logical screen name.
    case open
    /// Tap a control. `target` is the element's accessibility identifier.
    case tap
    /// Enter text into a field. `target` is the field identifier, `arg` is the text.
    case type
    /// Swipe on an element. `target` is the element, `arg` is `up`/`down`/`left`/`right`.
    case swipe
    /// Wait for an element to appear. `target` is its identifier, `arg` an optional timeout.
    case wait
    /// Assert a condition. `target` is the assertion (e.g. an element identifier that must
    /// exist), `arg` the expected value when applicable.
    case assert
}
