import Foundation

/// The outcome of running one scenario: pass/fail, the failure text if any, and how long
/// it took. Collected by a report run and rendered by `ScenarioReport`.
public struct ScenarioResult: Sendable, Equatable, Codable {
    public let id: String
    public let title: String
    public let stepCount: Int
    public let passed: Bool
    public let failure: String?
    public let duration: TimeInterval

    public init(id: String, title: String, stepCount: Int, passed: Bool, failure: String? = nil, duration: TimeInterval) {
        self.id = id
        self.title = title
        self.stepCount = stepCount
        self.passed = passed
        self.failure = failure
        self.duration = duration
    }
}
