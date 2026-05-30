/// Platform-specific dispatcher for scenario steps. Each runner (SwiftUI, AppKit, UIKit)
/// ships a conforming type that turns a `{ verb, target, arg }` triple into a real action
/// against that platform's UI (typically via the page objects). The registry both performs
/// the action and throws on an unknown `verb:target`, so a scenario can never reference
/// machinery that is not wired up.
///
/// `@MainActor` because every realistic Swift runner drives XCUI, which is main-actor.
public protocol StepRegistry {
    @MainActor
    func execute(_ step: Step) throws
}
