import AppCore
import AppModels
import CodeHighlighting
import MarkdownRendering

#if canImport(SwiftUI)
    import SwiftUI

    extension UI {
        /// Renders a served document with the shared `MarkdownRendering` pipeline (Splash
        /// highlighting injected via `Model.CodeHighlighting`), shown through
        /// `Markdown.DocumentView`. A reader text-size control (persisted) rescales the
        /// rendered text; the attributed string is rebuilt only when the markdown or the
        /// scale changes, not on every body evaluation.
        struct MarkdownReader: View {
            let markdown: String
            var title: String?
            var declaration: Model.DocPage.Declaration?

            @AppStorage("cupertino.reader.textScale") private var scale = 1.0
            @State private var attributed = NSAttributedString()

            private static let baseSize = Markdown.Theme().basePointSize
            private static let range = 0.7 ... 2.5
            private static let step = 0.1

            var body: some View {
                Markdown.DocumentView(attributed: attributed)
                    .task(id: markdown) { recompute() }
                    .onChange(of: scale) { _, _ in recompute() }
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            Button {
                                scale = max(Self.range.lowerBound, scale - Self.step)
                            } label: {
                                Image(systemName: "textformat.size.smaller")
                            }
                            .disabled(scale <= Self.range.lowerBound)
                            .help("Smaller text")

                            Button {
                                scale = min(Self.range.upperBound, scale + Self.step)
                            } label: {
                                Image(systemName: "textformat.size.larger")
                            }
                            .disabled(scale >= Self.range.upperBound)
                            .help("Larger text")
                        }
                    }
            }

            private func recompute() {
                attributed = Markdown.attributed(
                    markdown: markdown,
                    title: title,
                    declaration: declaration,
                    highlighter: Highlight.Splash(),
                    theme: Markdown.Theme(basePointSize: Self.baseSize * scale),
                )
            }
        }
    }
#endif
