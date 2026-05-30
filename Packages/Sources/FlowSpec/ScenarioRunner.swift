/// Walks a `Scenario`'s steps in order, dispatching each to a `StepRegistry`. Stops on the
/// first throw so the first failing step is the one reported.
public struct ScenarioRunner {
    public let registry: any StepRegistry

    public init(registry: any StepRegistry) {
        self.registry = registry
    }

    /// Run every step. Throws on the first failure, carrying the scenario id + step index
    /// so the test log pinpoints where it broke. `@MainActor` because `execute` is.
    @MainActor
    public func run(_ scenario: Scenario) throws {
        for (index, step) in scenario.steps.enumerated() {
            do {
                try registry.execute(step)
            } catch let error as StepRegistryError {
                throw ScenarioError.stepFailed(
                    scenarioID: scenario.id,
                    stepIndex: index,
                    step: step,
                    underlying: error,
                )
            }
        }
    }
}
