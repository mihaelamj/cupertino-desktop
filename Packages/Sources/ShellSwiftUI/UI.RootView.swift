import DesktopCore

#if canImport(SwiftUI)
import SwiftUI

extension UI {
    /// The SwiftUI app shell: an empty three-column navigation split view bound to
    /// the shared `RootModel`. Milestone M0 placeholder; per-feature SwiftUI
    /// packages populate the columns later, injected at the app composition root.
    public struct RootView: View {
        @Bindable private var model: RootModel

        public init(model: RootModel) {
            self._model = Bindable(model)
        }

        public var body: some View {
            NavigationSplitView {
                List(selection: $model.selectedFrameworkID) {
                    Text("Frameworks")
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("Cupertino")
            } content: {
                ContentUnavailableView(
                    "Select a framework",
                    systemImage: "books.vertical"
                )
            } detail: {
                if let id = model.selectedFrameworkID {
                    Text(id)
                } else {
                    ContentUnavailableView(
                        "Select a document",
                        systemImage: "doc.text"
                    )
                }
            }
        }
    }
}
#endif
