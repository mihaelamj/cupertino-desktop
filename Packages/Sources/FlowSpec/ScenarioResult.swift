import Foundation

/// The outcome of running one scenario: pass/fail, the failure text if any, and how long
/// it took. Collected by a report run and rendered by `ScenarioReport`.
public struct ScenarioResult: Sendable, Equatable, Codable {
    /// The UI target the scenario ran against (e.g. "Mobile SwiftUI"); the report groups
    /// results by it. Empty when ungrouped.
    public let uiTarget: String
    public let id: String
    public let title: String
    public let stepCount: Int
    public let passed: Bool
    public let failure: String?
    public let duration: TimeInterval

    public init(uiTarget: String = "", id: String, title: String, stepCount: Int, passed: Bool, failure: String? = nil, duration: TimeInterval) {
        self.uiTarget = uiTarget
        self.id = id
        self.title = title
        self.stepCount = stepCount
        self.passed = passed
        self.failure = failure
        self.duration = duration
    }
}
