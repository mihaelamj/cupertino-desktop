/// Wraps a registry error with scenario/step context so a report can point at which step
/// of which scenario failed.
public enum ScenarioError: Error, CustomStringConvertible {
    case stepFailed(scenarioID: String, stepIndex: Int, step: Step, underlying: StepRegistryError)

    public var description: String {
        switch self {
        case let .stepFailed(id, index, step, underlying):
            let arg = step.arg.map { " arg=\"\($0)\"" } ?? ""
            return "FlowSpec `\(id)` step #\(index + 1) `\(step.key)`\(arg): \(underlying)"
        }
    }
}
