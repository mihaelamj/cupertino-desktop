import AppModels
import Foundation
import Markdown

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

#if canImport(UIKit) || canImport(AppKit)
    public extension Markdown {
        /// How blocks are separated. AppKit and UIKit text views honor
        /// `NSParagraphStyle.paragraphSpacing`, so they get typographic spacing with a
        /// single newline between blocks; SwiftUI's `Text(AttributedString)` ignores
        /// paragraph spacing, so it gets an explicit blank line instead.
        enum BlockSpacing: Sendable {
            case paragraphSpacing
            case blankLine
        }

        /// Render a served document body to an `NSAttributedString`: normalize the dirty
        /// GFM, parse it, and walk the AST styling headings, paragraphs, lists, blockquotes,
        /// links, and code. Code blocks are rendered pretty: monospaced, inset, on a tinted
        /// background, with Swift syntax colors when a `Model.CodeHighlighting` is injected.
        /// An optional `declaration` is rendered as the leading signature block. `spacing`
        /// selects paragraph spacing (text views) or blank lines (SwiftUI `Text`).
        static func attributed(
            markdown: String,
            title: String? = nil,
            declaration: Model.DocPage.Declaration? = nil,
            highlighter: (any Model.CodeHighlighting)? = nil,
            theme: Theme = Theme(),
            spacing: BlockSpacing = .paragraphSpacing,
        ) -> NSAttributedString {
            let normalized = Normalizer.normalize(markdown, title: title)
            let renderer = Renderer(theme: theme, highlighter: highlighter, spacing: spacing)
            let output = NSMutableAttributedString()
            if let declaration {
                renderer.appendCodeBlock(declaration.code, language: declaration.language ?? "swift", into: output)
            }
            renderer.appendBlocks(in: parse(normalized.body), into: output)
            return output
        }

        /// Convenience over a `Model.DocPage` (uses its markdown, title, and declaration).
        static func attributed(
            page: Model.DocPage,
            highlighter: (any Model.CodeHighlighting)? = nil,
            theme: Theme = Theme(),
            spacing: BlockSpacing = .paragraphSpacing,
        ) -> NSAttributedString {
            attributed(markdown: page.markdown, title: page.title, declaration: page.declaration, highlighter: highlighter, theme: theme, spacing: spacing)
        }

        /// Resolve a link destination to a tappable URL: an absolute URL as-is, or a
        /// relative Apple-docs path (`/documentation/<framework>/<rest>`, fragment dropped)
        /// mapped to an `apple-docs://<framework>/<rest>` URI the reader can open. Other
        /// relative links return nil (styled but inert).
        static func documentURL(from destination: String?) -> URL? {
            guard let destination, !destination.isEmpty else { return nil }
            if let url = URL(string: destination), url.scheme != nil { return url }
            guard destination.hasPrefix("/documentation/") else { return nil }
            let path = destination.dropFirst("/documentation/".count)
            let withoutFragment = path.split(separator: "#", maxSplits: 1).first.map(String.init) ?? String(path)
            guard !withoutFragment.isEmpty else { return nil }
            return URL(string: "apple-docs://\(withoutFragment)")
        }
    }

    /// Walks a swift-markdown AST into an `NSAttributedString`. Block nodes append their
    /// rendering plus spacing; inline nodes append into the current run with the active
    /// font/color. Kept private so swift-markdown stays an implementation detail.
    private struct Renderer {
        let theme: Markdown.Theme
        let highlighter: (any Model.CodeHighlighting)?
        let spacing: Markdown.BlockSpacing

        // MARK: Blocks

        func appendBlocks(in container: Markup, into out: NSMutableAttributedString) {
            for child in container.children {
                appendBlock(child, into: out)
            }
        }

        private func appendBlock(_ markup: Markup, into out: NSMutableAttributedString) {
            switch markup {
            case let heading as Heading: appendHeading(heading, into: out)
            case let paragraph as Paragraph: appendParagraph(paragraph, into: out)
            case let code as CodeBlock: appendCodeBlock(code.code, language: code.language, into: out)
            case let quote as BlockQuote: appendBlockQuote(quote, into: out)
            case let list as UnorderedList: appendList(list, into: out)
            case let list as OrderedList: appendList(list, into: out)
            case let table as Table: appendTable(table, into: out)
            case is ThematicBreak: appendThematicBreak(into: out)
            default:
                let paragraph = NSMutableAttributedString()
                appendInline(markup, attributes: inlineAttributes(), into: paragraph)
                if paragraph.length > 0 {
                    out.append(paragraph)
                    out.append(blockBreak())
                }
            }
        }

        private func appendHeading(_ heading: Heading, into out: NSMutableAttributedString) {
            var attributes = inlineAttributes()
            attributes[.font] = theme.heading(level: heading.level).boldened
            attributes[.paragraphStyle] = headingParagraphStyle()
            let line = NSMutableAttributedString()
            appendInline(heading, attributes: attributes, into: line)
            out.append(line)
            out.append(blockBreak())
        }

        private func appendParagraph(_ paragraph: Paragraph, into out: NSMutableAttributedString) {
            var attributes = inlineAttributes()
            attributes[.paragraphStyle] = bodyParagraphStyle()
            let line = NSMutableAttributedString()
            appendInline(paragraph, attributes: attributes, into: line)
            out.append(line)
            out.append(blockBreak())
        }

        func appendCodeBlock(_ code: String, language: String?, into out: NSMutableAttributedString) {
            let trimmed = code.hasSuffix("\n") ? String(code.dropLast()) : code
            // Pad every line to the longest line's width so the per-glyph code background
            // forms one uniform block (an NSAttributedString background only covers glyphs,
            // not the full line, so unpadded lines render as ragged, different-width boxes).
            let lines = trimmed.components(separatedBy: "\n")
            let width = lines.map(\.count).max() ?? 0
            let padded = lines.map { $0.padding(toLength: width, withPad: " ", startingAt: 0) }.joined(separator: "\n")
            let paragraph = codeParagraphStyle()
            let tokens = highlighter?.tokens(in: padded, language: language)
                ?? [Model.SyntaxToken(text: padded, role: .plain)]
            let block = NSMutableAttributedString()
            for token in tokens {
                block.append(NSAttributedString(string: token.text, attributes: [
                    .font: theme.code,
                    .foregroundColor: theme.color(for: token.role),
                    .backgroundColor: theme.codeBackground,
                    .paragraphStyle: paragraph,
                ]))
            }
            out.append(block)
            out.append(blockBreak())
        }

        private func appendBlockQuote(_ quote: BlockQuote, into out: NSMutableAttributedString) {
            var attributes = inlineAttributes()
            attributes[.foregroundColor] = theme.secondary
            attributes[.font] = theme.body.italicized
            attributes[.paragraphStyle] = indentedParagraphStyle()
            let line = NSMutableAttributedString()
            for child in quote.children {
                if let paragraph = child as? Paragraph {
                    appendInline(paragraph, attributes: attributes, into: line)
                    line.append(NSAttributedString(string: "\n", attributes: attributes))
                } else {
                    appendBlock(child, into: line)
                }
            }
            out.append(line)
            out.append(blockBreak())
        }

        private func appendList(_ list: Markup, into out: NSMutableAttributedString) {
            let ordered = list is OrderedList
            var attributes = inlineAttributes()
            attributes[.paragraphStyle] = indentedParagraphStyle()
            var index = 1
            for case let item as ListItem in list.children {
                let marker = ordered ? "\(index).\t" : "•\t"
                let line = NSMutableAttributedString(string: marker, attributes: attributes)
                for child in item.children {
                    if let paragraph = child as? Paragraph {
                        appendInline(paragraph, attributes: attributes, into: line)
                    }
                }
                out.append(line)
                out.append(NSAttributedString(string: "\n", attributes: attributes))
                index += 1
            }
            out.append(blockBreak())
        }

        private func appendTable(_ table: Table, into out: NSMutableAttributedString) {
            var attributes = inlineAttributes()
            attributes[.font] = theme.code
            attributes[.paragraphStyle] = indentedParagraphStyle()
            func row(_ cells: [String]) {
                out.append(NSAttributedString(string: cells.joined(separator: "   |   ") + "\n", attributes: attributes))
            }
            row(table.head.cells.map(\.plainText))
            for bodyRow in table.body.rows {
                row(bodyRow.cells.map(\.plainText))
            }
            out.append(blockBreak())
        }

        private func appendThematicBreak(into out: NSMutableAttributedString) {
            out.append(NSAttributedString(string: "\u{00A0}\n", attributes: [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .strikethroughColor: theme.secondary,
                .paragraphStyle: bodyParagraphStyle(),
            ]))
        }

        // MARK: Inline

        private func appendInline(_ markup: Markup, attributes: [NSAttributedString.Key: Any], into out: NSMutableAttributedString) {
            for child in markup.children {
                switch child {
                case let text as Text:
                    out.append(NSAttributedString(string: text.string, attributes: attributes))
                case let code as InlineCode:
                    var codeAttributes = attributes
                    codeAttributes[.font] = theme.code
                    codeAttributes[.backgroundColor] = theme.codeBackground
                    out.append(NSAttributedString(string: code.code, attributes: codeAttributes))
                case let emphasis as Emphasis:
                    appendInline(emphasis, attributes: withFont(attributes, (attributes[.font] as? PlatformFont ?? theme.body).italicized), into: out)
                case let strong as Strong:
                    appendInline(strong, attributes: withFont(attributes, (attributes[.font] as? PlatformFont ?? theme.body).boldened), into: out)
                case let link as Link:
                    appendLink(link, attributes: attributes, into: out)
                case is SoftBreak:
                    out.append(NSAttributedString(string: " ", attributes: attributes))
                case is LineBreak:
                    out.append(NSAttributedString(string: "\n", attributes: attributes))
                default:
                    appendInline(child, attributes: attributes, into: out)
                }
            }
        }

        private func appendLink(_ link: Link, attributes: [NSAttributedString.Key: Any], into out: NSMutableAttributedString) {
            var linkAttributes = attributes
            linkAttributes[.foregroundColor] = theme.link
            linkAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            if let url = Markdown.documentURL(from: link.destination) {
                linkAttributes[.link] = url
            }
            appendInline(link, attributes: linkAttributes, into: out)
        }

        // MARK: Attributes and paragraph styles

        private func inlineAttributes() -> [NSAttributedString.Key: Any] {
            [.font: theme.body, .foregroundColor: theme.text]
        }

        private func withFont(_ attributes: [NSAttributedString.Key: Any], _ font: PlatformFont) -> [NSAttributedString.Key: Any] {
            var copy = attributes
            copy[.font] = font
            return copy
        }

        /// The separator between blocks. Text views use a single newline and rely on
        /// `NSParagraphStyle.paragraphSpacing`; SwiftUI `Text` ignores that, so it gets an
        /// explicit blank line.
        private func blockBreak() -> NSAttributedString {
            let separator = spacing == .blankLine ? "\n\n" : "\n"
            return NSAttributedString(string: separator, attributes: [.font: theme.body])
        }

        private func bodyParagraphStyle() -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.paragraphSpacing = theme.basePointSize * 0.6
            style.lineSpacing = theme.basePointSize * 0.12
            return style
        }

        private func headingParagraphStyle() -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.paragraphSpacingBefore = theme.basePointSize
            style.paragraphSpacing = theme.basePointSize * 0.3
            return style
        }

        private func codeParagraphStyle() -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.firstLineHeadIndent = 12
            style.headIndent = 12
            style.tailIndent = -12
            // No spacing BETWEEN the code lines: each line is its own paragraph, so any
            // paragraphSpacing punches a (background-less) gap between them and breaks the
            // block into separate rectangles. The spacing after the whole block is added by
            // blockBreak().
            style.paragraphSpacing = 0
            style.lineSpacing = 0
            return style
        }

        private func indentedParagraphStyle() -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.firstLineHeadIndent = 16
            style.headIndent = 16
            style.paragraphSpacing = theme.basePointSize * 0.3
            style.defaultTabInterval = 16
            style.tabStops = [NSTextTab(textAlignment: .left, location: 16)]
            return style
        }
    }
#endif
