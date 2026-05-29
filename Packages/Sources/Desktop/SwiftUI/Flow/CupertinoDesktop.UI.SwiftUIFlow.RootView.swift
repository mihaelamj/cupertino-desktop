import DesktopModels
import DesktopUI
import SearchFeature
import SearchSwiftUI
import SwiftUI

extension CupertinoDesktop.UI.SwiftUIFlow {
    /// The SwiftUI shell. Builds the search column through the shared
    /// `Search.Providing` seam (same contract the AppKit flow uses) and embeds
    /// the resulting controller via `ControllerView`.
    struct RootView: View {
        private let search = CupertinoDesktop.UI.Search.SwiftUIScreen()
        private let searchModel = CupertinoDesktop.Feature.Search.Model()

        var body: some View {
            NavigationSplitView {
                List {
                    Text("Frameworks")
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("Cupertino")
            } detail: {
                CupertinoDesktop.UI.ControllerView(search.makeController(model: searchModel))
            }
        }
    }
}
