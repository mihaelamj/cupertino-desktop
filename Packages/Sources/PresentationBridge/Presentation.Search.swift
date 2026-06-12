import AppModels
import Foundation
import Observation

public extension Presentation {
    enum Search {
        public enum Scope: String, CaseIterable, Sendable {
            case docs
            case everything
        }

        public enum Outcome: Sendable {
            case docs([Model.DocHit])
            case everything(Model.UnifiedResults)
        }

        public typealias State = Presentation.LoadState<Outcome>
    }

    /// The contract for the documentation-search view model, isolating the UI shells from the concrete feature packages.
    @MainActor
    protocol SearchViewModelProtocol: AnyObject, Observable, DocumentPageReader {
        var scope: Presentation.Search.Scope { get set }
        var text: String { get set }
        var sources: Set<Model.Source> { get set }
        var framework: String { get set }
        var minIOS: String { get set }
        var minMacOS: String { get set }
        var minSwift: String { get set }
        var limit: Int { get set }

        var state: Presentation.Search.State { get }
        var results: [Model.DocHit] { get }
        var docsTree: [Presentation.SearchResultNode] { get }
        var unified: Model.UnifiedResults? { get }
        var isLoading: Bool { get }
        var errorMessage: String? { get }
        var hasRun: Bool { get }

        func toggle(_ source: Model.Source)
        func run()
        func runDebounced()
        func readPage(_ uri: Model.DocURI) async throws -> Model.DocPage
    }
}
