import Markdown

/// Renders the markdown the server returns into display models for each UI framework
/// (`AttributedString` for SwiftUI, `NSAttributedString` for AppKit/UIKit). The pipeline
/// is: `Markdown.Normalizer` cleans the crawler's dirty GFM, swift-markdown parses it to
/// an AST, and a renderer walks the AST. Code highlighting is injected through the
/// `Model.CodeHighlighting` seam.
///
/// swift-markdown's module is also named `Markdown`; this enum shadows only the bare name,
/// so swift-markdown's types are used unqualified (`Document`, `Heading`, ...) while our
/// API stays under the `Markdown` anchor.
public enum Markdown {
    /// Parse already-normalized GFM into a swift-markdown document. Internal seam used by
    /// the renderer; isolates the swift-markdown import to this module.
    static func parse(_ markdown: String) -> Document {
        Document(parsing: markdown)
    }

    /// Number of top-level blocks; lets tests assert structure without importing
    /// swift-markdown.
    static func blockCount(of markdown: String) -> Int {
        parse(markdown).childCount
    }

    /// Top-level heading titles; lets tests assert that run-on headings parsed.
    static func headingTitles(in markdown: String) -> [String] {
        parse(markdown).children.compactMap { ($0 as? Heading)?.plainText }
    }
}
