# Cupertino Desktop: Backend Protocol (`Backend.Documentation`)

Status: **canonical.** This is the protocol of record. `docs/DESIGN.md` references it; this file owns the contract.

## 0. The law (restated)

Cupertino is a backend reached **only** through this protocol. We design the protocol for *us*: clean, typed, digestible. Every local way of reaching cupertino, the macOS `cupertino serve` subprocess or the in-process embedded read path, is an **adapter** that implements this protocol and is the **sole** place cupertino types or calls appear. There is no remote backend path. Nothing above an adapter, no feature, view, or view model, ever imports cupertino. Only protocol calls. The package import contract enforces this mechanically: only adapter packages may depend on the `cupertino` package.

The protocol lives in `BackendAPI`; the value types in `AppModels`; both are dependency-free seam packages.

## 1. Shape: capability slices composed into one backend

By interface segregation, the protocol is a set of focused capability protocols. A feature depends on the slice it needs (the search feature on `Searching`, the reader on `DocumentReading`), not the whole backend. `Backend.Documentation` composes them plus lifecycle; adapters implement the composition.

```swift
public enum Backend {}

public extension Backend {
    // Lifecycle, shared by every capability.
    protocol Connecting: Sendable {
        func connect() async throws
        func disconnect() async
    }

    protocol FrameworkBrowsing: Sendable {
        func listFrameworks() async throws -> [Model.Framework]
    }

    protocol DocumentReading: Sendable {
        func readDocument(_ uri: Model.DocURI) async throws -> Model.DocPage
    }

    protocol Searching: Sendable {
        func searchDocs(_ query: Model.DocsQuery) async throws -> [Model.DocHit]
        func searchSamples(_ query: Model.SampleQuery) async throws -> Model.SampleResults
        func searchPackages(_ query: Model.PackageQuery) async throws -> [Model.PackageHit]
        func searchEverything(_ query: Model.UnifiedQuery) async throws -> Model.UnifiedResults
    }

    protocol SampleBrowsing: Sendable {
        func listSamples(framework: String?, limit: Int) async throws -> [Model.SampleProject]
        func readSample(_ id: Model.SampleID) async throws -> Model.SampleProject
        func readSampleFile(_ id: Model.SampleID, path: String) async throws -> Model.SampleFile
    }

    protocol CodeIntelligence: Sendable {
        func searchSymbols(_ query: Model.SymbolQuery) async throws -> [Model.SymbolHit]
        func searchConformances(to protocolName: String, framework: String?, limit: Int) async throws -> [Model.SymbolHit]
        func searchPropertyWrappers(_ wrapper: String, framework: String?, limit: Int) async throws -> [Model.SymbolHit]
        func searchConcurrency(_ pattern: Model.ConcurrencyPattern, framework: String?, limit: Int) async throws -> [Model.SymbolHit]
        func searchGenerics(constraint: String, framework: String?, limit: Int) async throws -> [Model.SymbolHit]
        func inheritance(of symbol: String, direction: Model.InheritanceDirection, depth: Int, framework: String?) async throws -> Model.InheritanceTree
    }

    /// The whole backend: one adapter implements all capabilities, because one
    /// cupertino instance answers all of them. Features depend on the narrow
    /// slices above; composition roots vend `any Backend.Documentation`.
    typealias Documentation = Connecting & FrameworkBrowsing & DocumentReading
        & Searching & SampleBrowsing & CodeIntelligence
}
```

## 2. Value types (`AppModels`, our shapes)

All `Sendable`; `Identifiable`/`Hashable` where natural; `Codable` where an adapter decodes JSON straight into them (e.g. the subprocess adapter decoding `read_document`'s JSON).

### 2.1 Identifiers and enums

```swift
public extension Model {
    /// A documentation resource URI, e.g. apple-docs://swiftui/documentation_swiftui_view.
    /// Validated wrapper, not a bare String. Scheme is one of `Source.scheme`.
    struct DocURI: Hashable, Sendable, Codable { public let rawValue: String; public init?(_ raw: String) }

    /// A sample project identifier (cupertino's owner/repo slug).
    struct SampleID: Hashable, Sendable, Codable { public let rawValue: String; public init(_ raw: String) }

    /// Where a documentation hit came from. Drives icon, grouping, and which
    /// adapter source/tool answered it. Doc-like sources share `DocHit`.
    enum Source: String, Sendable, Codable, CaseIterable {
        case appleDocs, appleArchive, hig, swiftEvolution, swiftOrg, swiftBook, samples, packages
        public var scheme: String { ... } // apple-docs, apple-archive, hig, swift-evolution, ...
    }

    enum SymbolKind: String, Sendable, Codable {
        case `struct`, `class`, `actor`, `enum`, `protocol`, function, property, method,
             initializer, `subscript`, `operator`, typeAlias, macro, `case`, unknown
    }

    enum ConcurrencyPattern: String, Sendable, Codable, CaseIterable {
        case async, actor, sendable, mainActor, task, asyncSequence
    }

    enum InheritanceDirection: String, Sendable, Codable { case ancestors, descendants, both }
}
```

### 2.2 Platform availability

```swift
public extension Model {
    struct Availability: Hashable, Sendable, Codable {
        public let platform: Platform
        public let introducedAt: String?   // "17.0"
        public let deprecated: Bool
        public let beta: Bool
        public let unavailable: Bool

        public enum Platform: String, Sendable, Codable, CaseIterable {
            case iOS, macOS, tvOS, watchOS, visionOS
        }
    }

    /// A minimum-version floor used to filter search results.
    struct PlatformFloor: Hashable, Sendable, Codable {
        public var iOS: String?
        public var macOS: String?
        public var tvOS: String?
        public var watchOS: String?
        public var visionOS: String?
        public var swift: String?           // swift-evolution only
        public static let none = PlatformFloor()
    }
}
```

### 2.3 Frameworks, documents

```swift
public extension Model {
    struct Framework: Identifiable, Hashable, Sendable, Codable {
        public let id: String               // "swiftui"
        public let name: String             // "SwiftUI"
        public let documentCount: Int
    }

    /// A single search hit from a doc-like source (apple-docs, hig, swift-evolution,
    /// swift-org, swift-book, apple-archive). One uniform shape across those sources.
    struct DocHit: Identifiable, Hashable, Sendable, Codable {
        public let id: String               // stable id (uri-derived)
        public let uri: DocURI
        public let source: Source
        public let title: String
        public let framework: String?
        public let snippet: String          // ranked excerpt
        public let availability: [Availability]
        public let score: Double            // higher = better (normalized)
    }

    /// A fully read documentation page (`readDocument`). Carries structured fields
    /// plus the raw markdown body so the reader renders without a second fetch.
    struct DocPage: Hashable, Sendable, Codable {
        public let uri: DocURI
        public let source: Source
        public let title: String
        public let kind: SymbolKind
        public let abstract: String?
        public let declaration: Declaration?
        public let markdown: String          // rendered body
        public let sections: [Section]
        public let codeExamples: [CodeExample]
        public let availability: [Availability]
        public let relationships: Relationships

        public struct Declaration: Hashable, Sendable, Codable { public let code: String; public let language: String? }
        public struct Section: Hashable, Sendable, Codable { public let title: String; public let markdown: String }
        public struct CodeExample: Hashable, Sendable, Codable { public let code: String; public let language: String?; public let caption: String? }
        public struct Relationships: Hashable, Sendable, Codable {
            public let conformsTo: [String]
            public let inheritsFrom: [String]
            public let conformingTypes: [String]
            public let inheritedBy: [String]
        }
    }
}
```

### 2.4 Samples

```swift
public extension Model {
    struct SampleProject: Identifiable, Hashable, Sendable, Codable {
        public let id: SampleID
        public let title: String
        public let summary: String
        public let frameworks: [String]
        public let readme: String?           // markdown; nil until read in full
        public let webURL: String?
        public let filePaths: [String]       // empty until the project is read
        public let fileCount: Int
        public let deploymentTargets: [Availability.Platform: String]
    }

    struct SampleFile: Hashable, Sendable, Codable {
        public let projectID: SampleID
        public let path: String              // repo-relative
        public let filename: String
        public let language: String?         // for syntax highlighting
        public let contents: String
    }

    /// A file-level search hit inside samples (distinct from a project).
    struct SampleFileHit: Identifiable, Hashable, Sendable, Codable {
        public let id: String                // projectID|path
        public let projectID: SampleID
        public let path: String
        public let filename: String
        public let snippet: String
        public let score: Double
    }

    /// Sample search returns both project matches and file matches: distinct natures.
    struct SampleResults: Hashable, Sendable, Codable {
        public let projects: [SampleProject]
        public let files: [SampleFileHit]
    }
}
```

### 2.5 Packages, symbols, inheritance

```swift
public extension Model {
    struct PackageHit: Identifiable, Hashable, Sendable, Codable {
        public let id: String                // owner/repo/relpath
        public let owner: String
        public let repo: String
        public let path: String
        public let module: String?
        public let title: String
        public let snippet: String           // matched chunk
        public let score: Double
    }

    struct SymbolHit: Identifiable, Hashable, Sendable, Codable {
        public let id: String                // docURI#symbolName
        public let docURI: DocURI
        public let docTitle: String
        public let framework: String
        public let name: String
        public let kind: SymbolKind
        public let signature: String?
        public let attributes: [String]      // ["@MainActor", ...]
        public let conformances: [String]
        public let genericParams: String?
        public let isAsync: Bool
        public let isPublic: Bool
    }

    struct InheritanceTree: Hashable, Sendable, Codable {
        public let startURI: DocURI
        public let ancestors: [Node]
        public let descendants: [Node]
        public struct Node: Hashable, Sendable, Codable, Identifiable {
            public var id: String { uri.rawValue }
            public let uri: DocURI
            public let title: String
            public let children: [Node]
        }
    }
}
```

### 2.6 Queries

```swift
public extension Model {
    struct DocsQuery: Hashable, Sendable {
        public var text: String
        public var sources: Set<Source>     // doc-like sources to include; default = apple docs
        public var framework: String?
        public var language: String?
        public var floor: PlatformFloor
        public var limit: Int               // clamped by the adapter (cupertino max 100)
    }

    struct SampleQuery: Hashable, Sendable {
        public var text: String
        public var framework: String?
        public var floor: PlatformFloor
        public var includeFiles: Bool       // also match inside file contents
        public var limit: Int
    }

    struct PackageQuery: Hashable, Sendable {
        public var text: String
        public var appleImport: String?     // narrow to packages importing a framework
        public var floor: PlatformFloor
        public var limit: Int
    }

    /// The "everything" scope. One text, applied across all source natures.
    struct UnifiedQuery: Hashable, Sendable {
        public var text: String
        public var framework: String?
        public var floor: PlatformFloor
        public var limitPerSource: Int
    }

    struct UnifiedResults: Hashable, Sendable {
        public let docs: [DocHit]
        public let samples: SampleResults
        public let packages: [PackageHit]
        public let degraded: [String]       // sources that could not answer (with reason)
    }

    struct SymbolQuery: Hashable, Sendable {
        public var text: String?
        public var kind: SymbolKind?
        public var isAsync: Bool?
        public var framework: String?
        public var floor: PlatformFloor
        public var limit: Int
    }
}
```

## 3. Errors

One framework-agnostic error type, surfaced by every adapter, so the UI presents failures without knowing which adapter produced them.

```swift
public extension Backend {
    enum Failure: Error, Sendable {
        case notConnected
        case notFound(id: String)
        case unsupported(operation: String)   // an adapter that cannot answer a verb yet
        case transport(String)                 // subprocess/network failure (subprocess adapter)
        case corpusUnavailable(String)         // missing/locked DB or binary (embedded / first run)
        case decoding(String)                  // adapter could not map cupertino's output
        case backend(String)                   // cupertino reported an error
    }
}
```

## 4. Adapter mapping (the only place cupertino appears)

Each verb, the MCP tool the **subprocess** adapter calls, and the in-process service the **embedded** adapter calls. Output column notes the subprocess fidelity.

| Protocol verb | Subprocess adapter (MCP tool) | Subprocess output | Embedded adapter (service) |
|---|---|---|---|
| `listFrameworks` | `list_frameworks` | markdown -> parse | `DocsSearchService.listFrameworks()` |
| `readDocument` | `read_document` | **JSON (default)** -> decode | `ReadService.read` / `DocsSearchService.read(format: .json)` |
| `searchDocs` | `search` (source set) / `search_docs` / `search_hig` | markdown -> parse | `UnifiedSearchService` / `DocsSearchService.search` |
| `searchSamples` | `search_samples` | markdown -> parse | `Sample.Search.Service.search` |
| `searchPackages` | `search_packages` | markdown -> parse | `Search.PackagesSearcher.searchPackages` |
| `searchEverything` | `search_all` / `search` | markdown -> parse | `UnifiedSearchService.searchAll` |
| `listSamples` | `list_samples` | markdown -> parse | `Sample.Search.Service.listProjects` |
| `readSample` | `read_sample` | markdown -> parse | `getProject` + `listFiles` |
| `readSampleFile` | `read_sample_file` | text | `getFile` |
| `searchSymbols` | `search_symbols` | markdown -> parse | `Search.Database.searchSymbols` |
| `searchConformances` | `search_conformances` | markdown -> parse | `searchConformances` |
| `searchPropertyWrappers` | `search_property_wrappers` | markdown -> parse | `searchPropertyWrappers` |
| `searchConcurrency` | `search_concurrency` | markdown -> parse | `searchConcurrencyPatterns` |
| `searchGenerics` | `search_generics` | markdown -> parse | `searchByGenericConstraint` (+ cross-DB) |
| `inheritance` | `get_inheritance` | markdown -> parse | `resolveSymbolURIs` + `walkInheritance` |

Notes:
- **`read_document` is JSON by default**, so the document reader gets structured `DocPage` content even through the subprocess adapter. The markdown-scrape cost is confined to the *search-list* tools on the subprocess side; the embedded adapter avoids all scraping by mapping typed services.
- The subprocess adapter speaks the wire through the external `SwiftMCPClient` (its `MCPClient` over an injected `Transport.Channel`, over the neutral Foundation-only `SwiftMCPCore` wire types); the embedded adapter reuses cupertino's typed read services and result models. Both map into the `AppModels` above and expose nothing else.
- cupertino clamps `limit` to 100; adapters clamp our `limit` accordingly.

## 5. Versioning

This protocol is owned by us and versioned with the app, not with cupertino. When cupertino's surface changes, only an adapter changes. When a new capability is genuinely needed by a feature, it is added as a new method on the appropriate capability slice, and every adapter either implements it or throws `Failure.unsupported`.
