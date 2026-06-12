import AppCore
import AppModels
import PresentationBridge
import SwiftUI

public extension UI {
    struct SidebarFrameworksListView<VM: Presentation.FrameworkBrowserViewModelProtocol>: View {
        @Bindable var model: RootModel
        let frameworks: VM
        let source: Model.Source

        #if os(macOS)
            @Environment(\.dismiss) private var dismiss
        #endif

        public var body: some View {
            let searchQueryBinding = Binding<String>(
                get: { frameworks.searchQuery },
                set: { frameworks.searchQuery = $0 },
            )
            let sortOrderBinding = Binding<Presentation.FrameworkBrowser.SortOrder>(
                get: { frameworks.sortOrder },
                set: { frameworks.sortOrder = $0 },
            )

            VStack(alignment: .leading, spacing: 8) {
                #if os(macOS)
                    HStack(spacing: 8) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .accessibilityLabel("Back")

                        Text(UI.sourceDisplayName(source))
                            .font(.headline)
                            .fontWeight(.bold)
                            .lineLimit(1)

                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                #endif

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
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                        #if os(iOS)
                            .font(.title2)
                        #endif
                    }
                    #if os(macOS)
                    .menuStyle(.button)
                    .fixedSize()
                    #endif
                    .accessibilityLabel("Sort")
                    .accessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.sortButton)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                #if os(iOS)
                    .padding(.top, 8)
                #endif

                Group {
                    if frameworks.isLoading {
                        ProgressView("Loading \(source.itemTerm.lowercased())")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = frameworks.errorMessage {
                        ContentUnavailableView("Could not load \(source.itemTerm.lowercased())", systemImage: "exclamationmark.triangle", description: Text(error))
                    } else {
                        List(frameworks.frameworks, selection: $model.selectedFrameworkID) { framework in
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
                            .tag(framework.id)
                            .accessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.row(framework.id))
                        }
                        .accessibilityIdentifier(UI.AccessibilityID.FrameworkBrowser.sidebar)
                    }
                }
            }
            #if os(iOS)
            .navigationTitle(UI.sourceDisplayName(source))
            #endif
        }
    }
}
