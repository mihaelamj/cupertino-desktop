/// A cross-runner UI scenario, decoded from `scenarios/*.json` and executed by whichever
/// runner (SwiftUI/AppKit/UIKit) hosts a matching `StepRegistry`. One scenario, many UIs.
public struct Scenario: Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let actor: String?
    public let preconditions: [String]
    public let tags: [String]
    public let steps: [Step]

    public init(
        id: String,
        title: String,
        actor: String? = nil,
        preconditions: [String] = [],
        tags: [String] = [],
        steps: [Step],
    ) {
        self.id = id
        self.title = title
        self.actor = actor
        self.preconditions = preconditions
        self.tags = tags
        self.steps = steps
    }

    enum CodingKeys: String, CodingKey {
        case id, title, actor, preconditions, tags, steps
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        actor = try container.decodeIfPresent(String.self, forKey: .actor)
        preconditions = try container.decodeIfPresent([String].self, forKey: .preconditions) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        steps = try container.decode([Step].self, forKey: .steps)
    }
}
