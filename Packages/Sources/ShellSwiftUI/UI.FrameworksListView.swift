import AppCore
import AppModels
import PresentationBridge
import SwiftUI

public extension UI {
    struct FrameworksListView<VM: Presentation.FrameworkBrowserViewModelProtocol>: View {
        @Bindable var model: RootModel
        let frameworks: VM
        let source: Model.Source

        public var body: some View {
            let searchQueryBinding = Binding<String>(
                get: { frameworks.searchQuery },
                set: { frameworks.searchQuery = $0 },
            )
            let sortOrderBinding = Binding<Presentation.FrameworkBrowser.SortOrder>(
                get: { frameworks.sortOrder },
                set: { frameworks.sortOrder = $0 },
            )

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    TextField("Search \(source.itemTerm)", text: searchQueryBinding)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.searchField)

                    Menu {
                        Picker("Sort By", selection: sortOrderBinding) {
                            Label("Name", systemImage: "textformat")
                                .tag(Presentation.FrameworkBrowser.SortOrder.name)
                                .accessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.sortByNameOption)
                            Label("Count", systemImage: "number")
                                .tag(Presentation.FrameworkBrowser.SortOrder.count)
                                .accessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.sortByCountOption)
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .font(.title2)
                    }
                    .fixedSize()
                    .accessibilityLabel("Sort")
                    .accessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.sortButton)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)

                Group {
                    if frameworks.isLoading {
                        ProgressView("Loading \(source.itemTerm.lowercased())")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = frameworks.errorMessage {
                        ContentUnavailableView("Could not load \(source.itemTerm.lowercased())", systemImage: "exclamationmark.triangle", description: Text(error))
                    } else {
                        List(frameworks.frameworks) { framework in
                            NavigationLink(value: NavigationDestination.documents(framework)) {
                                HStack(spacing: 12) {
                                    Text(framework.displayName)
                                        .font(.title3)
                                        .lineLimit(1)
                                    Spacer(minLength: 8)
                                    Text(framework.documentCount.formatted())
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                .padding(.vertical, 3)
                            }
                            .accessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.row(framework.id))
                        }
                    }
                }
            }
            .navigationTitle(UI.sourceDisplayName(source))
        }
    }
}
