import DesktopModels
import DesktopUI
import SearchFeature
import SwiftUI

public extension CupertinoDesktop.UI.Search {
    /// The SwiftUI search screen. Milestone M0 placeholder; binds to the shared
    /// `Feature.Search.Model` and grows a real query UI in M3.
    struct SwiftUIView: View {
        private let model: CupertinoDesktop.Feature.Search.Model

        public init(model: CupertinoDesktop.Feature.Search.Model) {
            self.model = model
        }

        public var body: some View {
            ContentUnavailableView("Search (SwiftUI)", systemImage: "magnifyingglass")
        }
    }
}
