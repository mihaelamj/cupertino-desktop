import AppModels
import Foundation
@testable import MarkdownRendering
import Testing

@Suite("Markdown")
struct MarkdownRenderingTests {
    @Test("swift-markdown parses GFM into a document")
    func parsesGFM() {
        // Heading, paragraph, code block: three top-level blocks.
        #expect(Markdown.blockCount(of: "# Title\n\nA paragraph with `code`.\n\n```swift\nlet x = 1\n```") == 3)
    }

    // The fixture is intentionally a single run-on per line (mirroring the crawler).
    // swiftlint:disable line_length
    /// A representative slice of the dirty Apple-docs body `read_document` returns, with
    /// frontmatter, a title suffix, a breadcrumb list, a `Kind# Title` run-on, a run-on
    /// availability string, an untagged declaration fence, and a link list that runs into
    /// the next heading.
    private static let dirty = """
    ---
    source: https://developer.apple.com/documentation/swiftui/state
    crawled: 2026-05-09T22:17:44Z
    ---

    # State | Apple Developer Documentation

    - [ SwiftUI ](/documentation/swiftui)

    - [ State ](/documentation/swiftui/state)

    -  State

    Structure# State

    A property wrapper type that can read and write a value managed by SwiftUI.iOS 13.0+iPadOS 13.0+macOS 10.15+watchOS 6.0+

    ```
    @frozen @propertyWrapper
    struct State<Value>
    ```

    ## [ Mentioned in ](/documentation/swiftui/state#mentions)

    [ Managing user interface state ](/documentation/swiftui/managing-user-interface-state)[ Performing a search operation ](/documentation/swiftui/performing-a-search-operation)## [Overview](/documentation/swiftui/state#overview)

    Use state as the single source of truth.
    """
    // swiftlint:enable line_length

    @Test("the normalizer cleans the served body and lifts the title")
    func normalizesDirtyBody() {
        let result = Markdown.Normalizer.normalize(Self.dirty)

        // Title lifted and the site suffix stripped.
        #expect(result.title == "State")
        let body = result.body

        // Frontmatter, breadcrumbs, the H1, and the `Kind# Title` run-on are gone.
        #expect(!body.contains("crawled:"))
        #expect(!body.contains("/documentation/swiftui)"))
        #expect(!body.contains("Structure# State"))
        #expect(!body.contains("Apple Developer Documentation"))

        // Availability is lifted off the abstract into monospaced chips on their own line.
        #expect(body.contains("`iOS 13.0+`"))
        #expect(body.contains("`macOS 10.15+`"))
        #expect(!body.contains("SwiftUI.iOS 13.0+"))

        // The untagged declaration fence is tagged Swift.
        #expect(body.contains("```swift"))

        // The run-on Overview heading now parses as a real heading and the link list split.
        let headings = Markdown.headingTitles(in: body).map { $0.trimmingCharacters(in: .whitespaces) }
        #expect(headings.contains("Overview"))
        #expect(headings.contains("Mentioned in"))
    }

    #if canImport(AppKit) || canImport(UIKit)
        /// A highlighter that tags the leading `let` as a keyword, so the test can assert
        /// the renderer styled the code run, independent of Splash.
        private struct FakeHighlighter: Model.CodeHighlighting {
            func tokens(in _: String, language _: String?) -> [Model.SyntaxToken] {
                [Model.SyntaxToken(text: "let", role: .keyword), Model.SyntaxToken(text: " x = 1", role: .plain)]
            }
        }

        @Test("code blocks render monospaced with highlighted token colors")
        func rendersCodePretty() {
            let theme = Markdown.Theme()
            let attributed = Markdown.attributed(markdown: "```swift\nlet x = 1\n```", highlighter: FakeHighlighter(), theme: theme)
            let whole = NSRange(location: 0, length: attributed.length)

            var sawCodeFont = false
            attributed.enumerateAttribute(.font, in: whole) { value, _, _ in
                if let font = value as? PlatformFont, font == theme.code { sawCodeFont = true }
            }
            var sawKeywordColor = false
            attributed.enumerateAttribute(.foregroundColor, in: whole) { value, _, _ in
                if let color = value as? PlatformColor, color == theme.color(for: .keyword) { sawKeywordColor = true }
            }

            #expect(sawCodeFont) // code is monospaced
            #expect(sawKeywordColor) // the keyword token got its highlight color
        }

        @Test("document links map relative Apple-docs paths to apple-docs URIs")
        func resolvesDocumentLinks() {
            #expect(Markdown.documentURL(from: "/documentation/swiftui/binding")?.absoluteString == "apple-docs://swiftui/binding")
            // Fragment is dropped (intra-page anchors are not separate documents).
            #expect(Markdown.documentURL(from: "/documentation/swiftui/state#overview")?.absoluteString == "apple-docs://swiftui/state")
            // Absolute URLs pass through unchanged.
            #expect(Markdown.documentURL(from: "https://swift.org")?.absoluteString == "https://swift.org")
            // Non-doc relative links stay inert.
            #expect(Markdown.documentURL(from: "/design/human-interface-guidelines/buttons") == nil)
        }
    #endif
}
