import AppCore
import AppModels
import PresentationBridge

#if canImport(SwiftUI)
    import SwiftUI

    public extension UI {
        enum NavigationDestination: Hashable, Sendable {
            case frameworks(Model.Source)
            case documents(Model.Framework)
        }

        /// The SwiftUI app shell: a multi-stage navigation split view.
        /// The first level is a list of database sources. Selecting a source reveals
        /// its frameworks. Selecting a framework reveals its documents.
        struct RootView<VM: Presentation.FrameworkBrowserViewModelProtocol>: View {
            @Bindable private var model: RootModel
            private let frameworks: VM
            @State private var columnVisibility = NavigationSplitViewVisibility.all
            @Environment(\.horizontalSizeClass) private var horizontalSizeClass
            @Environment(\.verticalSizeClass) private var verticalSizeClass
            @State private var navigationPath: [NavigationDestination] = []
            @State private var sidebarPath: [NavigationDestination] = []

            private var activeHorizontalSizeClass: UserInterfaceSizeClass? {
                #if os(iOS)
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        return horizontalSizeClass
                    } else {
                        return .compact
                    }
                #else
                    if verticalSizeClass == .compact {
                        return .regular
                    }
                    return horizontalSizeClass
                #endif
            }

            private var sources: [Model.Source] {
                frameworks.sources
            }

            public init(model: RootModel, frameworks: VM) {
                _model = Bindable(model)
                self.frameworks = frameworks
            }

            private var compactView: some View {
                NavigationStack(path: $navigationPath) {
                    compactSidebar
                        .navigationTitle("Cupertino (SwiftUI)")
                        .task { frameworks.onAppeared() }
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
            }

            private var regularView: some View {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    NavigationStack(path: $sidebarPath) {
                        sidebar
                            .navigationTitle("Cupertino (SwiftUI)")
                            .task { frameworks.onAppeared() }
                            .navigationDestination(for: NavigationDestination.self) { destination in
                                sidebarDestinationView(for: destination)
                            }
                    }
                    .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 420)
                } detail: {
                    detailColumn
                }
                .navigationSplitViewStyle(.balanced)
            }

            public var body: some View {
                Group {
                    if activeHorizontalSizeClass == .compact {
                        compactView
                    } else {
                        regularView
                    }
                }
                .environment(\.horizontalSizeClass, activeHorizontalSizeClass ?? .compact)
                .onChange(of: model.selectedFrameworkID) { _, newID in
                    frameworks.selectFramework(newID)
                }
                .onChange(of: frameworks.frameworks.map(\.id)) { _, ids in
                    autoSelectFirstIfNeeded(ids)
                }
                .onChange(of: activeHorizontalSizeClass) { _, newClass in
                    handleSizeClassChange(newClass)
                }
                .onChange(of: navigationPath) { _, newPath in
                    handleNavigationPathChange(newPath)
                }
                .onChange(of: sidebarPath) { _, newPath in
                    handleSidebarPathChange(newPath)
                }
            }

            private func handleSizeClassChange(_ newClass: UserInterfaceSizeClass?) {
                if newClass == .compact {
                    sidebarPath = []
                    var path: [NavigationDestination] = []
                    if let source = frameworks.selectedSource {
                        path.append(.frameworks(source))
                        if let selectedFramework = frameworks.selectedFramework {
                            path.append(.documents(selectedFramework))
                        }
                    }
                    navigationPath = path
                } else if newClass == .regular {
                    navigationPath = []
                    if let source = frameworks.selectedSource {
                        sidebarPath = [.frameworks(source)]
                    } else {
                        sidebarPath = []
                    }
                    if verticalSizeClass == .regular {
                        if model.selectedFrameworkID == nil, let first = frameworks.frameworks.first {
                            model.selectedFrameworkID = first.id
                        }
                    }
                    columnVisibility = .all
                }
            }

            private func handleSidebarPathChange(_ newPath: [NavigationDestination]) {
                guard activeHorizontalSizeClass == .regular else { return }
                if let last = newPath.last {
                    if case let .frameworks(source) = last {
                        if frameworks.selectedSource != source {
                            frameworks.selectSource(source)
                        }
                    }
                } else {
                    if frameworks.selectedSource != nil {
                        frameworks.selectSource(nil)
                    }
                }
            }

            private func handleNavigationPathChange(_ newPath: [NavigationDestination]) {
                guard activeHorizontalSizeClass == .compact else { return }
                if let last = newPath.last {
                    switch last {
                    case let .frameworks(source):
                        if frameworks.selectedSource != source {
                            frameworks.selectSource(source)
                        }
                        if model.selectedFrameworkID != nil {
                            model.selectedFrameworkID = nil
                        }
                    case let .documents(framework):
                        if case let .frameworks(source) = newPath.first {
                            if frameworks.selectedSource != source {
                                frameworks.selectSource(source)
                            }
                        }
                        if model.selectedFrameworkID != framework.id {
                            model.selectedFrameworkID = framework.id
                        }
                    }
                } else {
                    if frameworks.selectedSource != nil {
                        frameworks.selectSource(nil)
                    }
                    if model.selectedFrameworkID != nil {
                        model.selectedFrameworkID = nil
                    }
                }
            }

            private func autoSelectFirstIfNeeded(_ ids: [String]) {
                #if os(macOS)
                    if model.selectedFrameworkID == nil, let first = ids.first {
                        model.selectedFrameworkID = first
                    }
                #else
                    if activeHorizontalSizeClass == .regular, verticalSizeClass == .regular {
                        if model.selectedFrameworkID == nil, let first = ids.first {
                            model.selectedFrameworkID = first
                        }
                    }
                #endif
            }

            @ViewBuilder
            private func destinationView(for destination: NavigationDestination) -> some View {
                switch destination {
                case let .frameworks(source):
                    FrameworksListView(model: model, frameworks: frameworks, source: source)
                        .onAppear {
                            frameworks.selectSource(source)
                        }
                case let .documents(framework):
                    DocumentsListView(model: model, frameworks: frameworks, framework: framework)
                }
            }

            @ViewBuilder
            private func sidebarDestinationView(for destination: NavigationDestination) -> some View {
                switch destination {
                case let .frameworks(source):
                    SidebarFrameworksListView(model: model, frameworks: frameworks, source: source)
                        .onAppear {
                            frameworks.selectSource(source)
                        }
                case .documents:
                    EmptyView()
                }
            }

            private func displayName(for source: Model.Source) -> String {
                source.displayName
            }

            private func iconName(for source: Model.Source) -> String {
                source.iconName
            }

            private var compactSidebar: some View {
                List(sources, id: \.self) { source in
                    NavigationLink(value: NavigationDestination.frameworks(source)) {
                        Label(displayName(for: source), systemImage: iconName(for: source))
                    }
                    .accessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.sourceRow(source.rawValue))
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.sidebar)
            }

            private var sidebar: some View {
                List(sources, id: \.self) { source in
                    NavigationLink(value: NavigationDestination.frameworks(source)) {
                        Label(displayName(for: source), systemImage: iconName(for: source))
                    }
                    .accessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.sourceRow(source.rawValue))
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.sidebar)
            }

            private var detailColumn: some View {
                Group {
                    if let selectedFramework = frameworks.selectedFramework {
                        NavigationStack {
                            if let markdown = frameworks.selectedMarkdown {
                                MarkdownReader(markdown: markdown, title: frameworks.selectedDocumentTitle)
                                    .accessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.reader)
                                    .navigationTitle(frameworks.selectedDocumentTitle ?? "")
                            } else if frameworks.isLoadingDocument {
                                ProgressView()
                            } else if let error = frameworks.documentError {
                                ContentUnavailableView("Could not load document", systemImage: "exclamationmark.triangle", description: Text(error))
                            } else {
                                DocumentsListView(model: model, frameworks: frameworks, framework: selectedFramework)
                            }
                        }
                    } else {
                        let emptyTitle = if let source = frameworks.selectedSource {
                            "Select a \(source.singularItemTerm)"
                        } else {
                            "Select a database"
                        }
                        ContentUnavailableView(emptyTitle, systemImage: "doc.text")
                            .navigationTitle("Cupertino")
                    }
                }
            }
        }

        static func sourceDisplayName(_ source: Model.Source) -> String {
            switch source {
            case .appleDocs: "Apple Docs"
            case .hig: "HIG"
            case .swiftEvolution: "Swift Evolution"
            case .swiftOrg: "Swift.org"
            case .swiftBook: "Swift Book"
            case .appleArchive: "Apple Archive"
            case .samples: "Samples"
            case .packages: "Packages"
            default: source.displayName
            }
        }
    }
#endif
