import CupertinoDataKit

/// A minimal `Search.Result` for the given URI and source, enough to map to a DocHit.
func docResult(_ uri: String, source: String) -> Search.Result {
    Search.Result(uri: uri, source: source, framework: "", title: uri, summary: "", filePath: "", wordCount: 1, rank: -1)
}

func packageResult(_ uri: String, module: String, title: String, rank: Double = -1.0) -> Search.Result {
    Search.Result(
        uri: uri,
        source: "packages",
        framework: module,
        title: title,
        summary: "Package hit for \(title)",
        filePath: "",
        wordCount: 5,
        rank: rank,
    )
}

func sampleProject() -> Sample.Index.Project {
    Sample.Index.Project(
        id: "landmarks",
        title: "Landmarks",
        description: "Build an app for discovering landmarks.",
        frameworks: ["SwiftUI"],
        readme: "# Landmarks",
        webURL: "https://developer.apple.com/tutorials/swiftui",
        zipFilename: "landmarks.zip",
        fileCount: 1,
        totalSize: 42,
        deploymentTargets: ["iOS": "17.0"],
    )
}

func symbolResult(uri: String, name: String, kind: String) -> Search.SymbolSearchResult {
    Search.SymbolSearchResult(
        docUri: uri,
        docTitle: name,
        framework: "swiftui",
        symbolName: name,
        symbolKind: kind,
        signature: "public \(kind) \(name)",
        attributes: "@MainActor",
        conformances: "Sendable, View",
        isAsync: false,
        isPublic: true,
        genericParams: "T: View",
    )
}

/// A fake `Search.DocumentReading`: the adapter depends on the protocol, so the read
/// engine is replaced with canned data, no SQLite, no corpus.
struct FakeDataSource: Search.DocumentReading {
    var frameworks: [String: Int] = [:]
    var documents: [String: String] = [:]
    var results: [Search.Result] = []

    // swiftlint:disable:next function_parameter_count
    func search(
        query _: String, source _: String?, framework _: String?, language _: String?,
        limit _: Int, includeArchive _: Bool,
        minIOS _: String?, minMacOS _: String?, minTvOS _: String?,
        minWatchOS _: String?, minVisionOS _: String?, minSwift _: String?,
    ) async throws -> [Search.Result] {
        results
    }

    func getDocumentContent(uri: String, format _: Search.DocumentFormat) async throws -> String? {
        documents[uri]
    }

    func listFrameworks() async throws -> [String: Int] {
        frameworks
    }

    func documentCount() async throws -> Int {
        documents.count
    }

    func disconnect() async {}
}

actor FakeSampleReader: Sample.Index.Reader {
    struct Calls {
        var projectFramework: String?
        var projectMinIOS: String?
        var filePlatform: String?
        var fileMinVersion: String?
    }

    private var projects: [Sample.Index.Project]
    private var fileResults: [Sample.Index.FileSearchResult]
    private var files: [Sample.Index.File]
    private var recordedCalls = Calls()

    init(
        projects: [Sample.Index.Project] = [],
        fileResults: [Sample.Index.FileSearchResult] = [],
        files: [Sample.Index.File] = [],
    ) {
        self.projects = projects
        self.fileResults = fileResults
        self.files = files
    }

    // swiftlint:disable:next function_parameter_count
    func searchProjects(
        query _: String,
        framework: String?,
        limit _: Int,
        minIOS: String?,
        minMacOS _: String?,
        minTvOS _: String?,
        minWatchOS _: String?,
        minVisionOS _: String?,
    ) async throws -> [Sample.Index.Project] {
        recordedCalls.projectFramework = framework
        recordedCalls.projectMinIOS = minIOS
        return projects
    }

    // swiftlint:disable:next function_parameter_count
    func searchFiles(
        query _: String,
        projectId _: String?,
        fileExtension _: String?,
        limit _: Int,
        platform: String?,
        minVersion: String?,
    ) async throws -> [Sample.Index.FileSearchResult] {
        recordedCalls.filePlatform = platform
        recordedCalls.fileMinVersion = minVersion
        return fileResults
    }

    func searchSymbolsForFiles(query _: String, limit _: Int) async throws -> Set<String> {
        []
    }

    func searchFilesByGenericConstraint(constraint _: String, framework _: String?, limit _: Int) async throws -> [Sample.Index.FileSearchResult] {
        []
    }

    func getProject(id: String) async throws -> Sample.Index.Project? {
        projects.first { $0.id == id }
    }

    func listProjects(framework _: String?, limit _: Int) async throws -> [Sample.Index.Project] {
        projects
    }

    func projectCount() async throws -> Int {
        projects.count
    }

    func getFile(projectId: String, path: String) async throws -> Sample.Index.File? {
        files.first { $0.projectId == projectId && $0.path == path }
    }

    func listFiles(projectId: String, folder _: String?) async throws -> [Sample.Index.File] {
        files.filter { $0.projectId == projectId }
    }

    func fileCount() async throws -> Int {
        files.count
    }

    func disconnect() async {}

    func calls() -> Calls {
        recordedCalls
    }
}

actor FakePackageSearcher: Search.PackagesSearcher {
    struct Calls {
        var query: String?
        var limit: Int?
        var availabilityPlatform: String?
        var availabilityMinVersion: String?
        var swiftToolsMinVersion: String?
        var appleImport: String?
        var genericConstraint: String?
        var genericFramework: String?
        var genericLimit: Int?
    }

    private var results: [Search.Result]
    private var genericResults: [Search.Result]
    private var recordedCalls = Calls()

    init(
        results: [Search.Result] = [],
        genericResults: [Search.Result] = [],
    ) {
        self.results = results
        self.genericResults = genericResults
    }

    func searchPackages(
        query: String,
        limit: Int,
        availability: Search.AvailabilityFilter?,
        swiftTools: Search.SwiftToolsFilter?,
        appleImport: String?,
    ) async throws -> [Search.Result] {
        recordedCalls.query = query
        recordedCalls.limit = limit
        recordedCalls.availabilityPlatform = availability?.platform
        recordedCalls.availabilityMinVersion = availability?.minVersion
        recordedCalls.swiftToolsMinVersion = swiftTools?.minVersion
        recordedCalls.appleImport = appleImport
        return Array(results.prefix(limit))
    }

    func searchPackageSymbolsByGenericConstraint(
        constraint: String,
        framework: String?,
        limit: Int,
    ) async throws -> [Search.Result] {
        recordedCalls.genericConstraint = constraint
        recordedCalls.genericFramework = framework
        recordedCalls.genericLimit = limit
        return Array(genericResults.prefix(limit))
    }

    func calls() -> Calls {
        recordedCalls
    }
}

actor FakeSymbolReader: Search.SymbolReading {
    struct Calls {
        var symbolKind: String?
        var symbolFramework: String?
        var fetchMinimaURIs: [String] = []
        var protocolName: String?
        var wrapper: String?
        var concurrencyPattern: String?
        var genericConstraint: String?
        var inheritanceStartURI: String?
        var inheritanceDirection: Search.InheritanceDirection?
        var inheritanceDepth: Int?
    }

    private var symbolResults: [Search.SymbolSearchResult]
    private var platformMinima: [String: Search.PlatformMinima]
    private var inheritanceCandidates: [Search.InheritanceCandidate]
    private var inheritanceTree: Search.InheritanceTree
    private var recordedCalls = Calls()

    init(
        symbolResults: [Search.SymbolSearchResult] = [],
        platformMinima: [String: Search.PlatformMinima] = [:],
        inheritanceCandidates: [Search.InheritanceCandidate] = [],
        inheritanceTree: Search.InheritanceTree = Search.InheritanceTree(startURI: "apple-docs://swiftui/view", ancestors: [], descendants: []),
    ) {
        self.symbolResults = symbolResults
        self.platformMinima = platformMinima
        self.inheritanceCandidates = inheritanceCandidates
        self.inheritanceTree = inheritanceTree
    }

    func searchSymbols(
        query _: String?,
        kind: String?,
        isAsync _: Bool?,
        framework: String?,
        limit _: Int,
    ) async throws -> [Search.SymbolSearchResult] {
        recordedCalls.symbolKind = kind
        recordedCalls.symbolFramework = framework
        return symbolResults
    }

    func searchPropertyWrappers(wrapper: String, framework _: String?, limit _: Int) async throws -> [Search.SymbolSearchResult] {
        recordedCalls.wrapper = wrapper
        return symbolResults
    }

    func searchConcurrencyPatterns(pattern: String, framework _: String?, limit _: Int) async throws -> [Search.SymbolSearchResult] {
        recordedCalls.concurrencyPattern = pattern
        return symbolResults
    }

    func searchConformances(protocolName: String, framework _: String?, limit _: Int) async throws -> [Search.SymbolSearchResult] {
        recordedCalls.protocolName = protocolName
        return symbolResults
    }

    func searchByGenericConstraint(constraint: String, framework _: String?, limit _: Int) async throws -> [Search.SymbolSearchResult] {
        recordedCalls.genericConstraint = constraint
        return symbolResults
    }

    func resolveSymbolURIs(title _: String) async throws -> [Search.InheritanceCandidate] {
        inheritanceCandidates
    }

    func walkInheritance(
        startURI: String,
        direction: Search.InheritanceDirection,
        maxDepth: Int,
    ) async throws -> Search.InheritanceTree {
        recordedCalls.inheritanceStartURI = startURI
        recordedCalls.inheritanceDirection = direction
        recordedCalls.inheritanceDepth = maxDepth
        return inheritanceTree
    }

    func fetchPlatformMinima(uris: [String]) async throws -> [String: Search.PlatformMinima] {
        recordedCalls.fetchMinimaURIs = uris
        return platformMinima
    }

    func getFrameworkAvailability(framework _: String) async -> Search.FrameworkAvailability {
        .empty
    }

    func listResourceEntries(mode _: Search.ResourceListMode) async throws -> [Search.URIResource] {
        []
    }

    func calls() -> Calls {
        recordedCalls
    }
}
