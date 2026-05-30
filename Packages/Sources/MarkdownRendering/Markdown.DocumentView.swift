#if canImport(SwiftUI)
    import SwiftUI

    public extension Markdown {
        /// A SwiftUI view that displays a rendered document. It shows the same
        /// `NSAttributedString` the AppKit/UIKit readers use, bridged to `AttributedString`
        /// and rendered with `Text` inside a `ScrollView`, so headings, inline styling,
        /// links, and monospaced, syntax-colored code all display. (Block backgrounds such
        /// as the code tint are an `NSAttributedString`-only nicety the native readers keep;
        /// `Text` drops them, which is an acceptable trade for reliable SwiftUI layout.)
        struct DocumentView: View {
            private let text: AttributedString

            public init(attributed: NSAttributedString) {
                // Keep the platform font/color attributes (Text renders them); filtering to
                // the SwiftUI scope would drop the UIFont/NSFont and leave plain text.
                text = AttributedString(attributed)
            }

            public var body: some View {
                ScrollView {
                    Text(text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
    }
#endif
