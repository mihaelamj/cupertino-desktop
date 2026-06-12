import AppCore
import AppModels

public extension Feature.FrameworkBrowser.ViewModel {
    /// Classifies frameworks into their respective sources for filtering and placeholders.
    static func belongs(framework: Model.Framework, to source: Model.Source) -> Bool {
        let id = framework.id.lowercased()
        switch source {
        case .appleDocs:
            let nonAppleDocs: Set = [
                "swift-evolution", "swift-org", "swift-book",
                "components", "foundations", "general", "inputs", "patterns", "technologies",
                "cocoa", "objectivec", "appkit", "samples", "packages",
            ]
            return !nonAppleDocs.contains(id)
        case .appleArchive:
            let archiveFrameworks: Set = [
                "appkit", "cocoa", "coreaudio", "coredata", "corefoundation", "coregraphics",
                "coreimage", "coretext", "foundation", "objectivec", "performance",
                "quartzcore", "security", "uikit",
            ]
            return archiveFrameworks.contains(id)
        case .hig:
            return ["components", "foundations", "general", "inputs", "patterns", "technologies"].contains(id)
        case .swiftEvolution:
            return id == "swift-evolution"
        case .swiftOrg:
            return id == "swift-org"
        case .swiftBook:
            return id == "swift-book"
        case .samples:
            return id == "samples"
        case .packages:
            return id == "packages"
        default:
            return id == source.rawValue.lowercased()
        }
    }
}
