import Foundation

public extension Markdown {
    /// The result of normalizing a served document: the cleaned title (site suffix
    /// removed) and a clean GFM body the parser can render faithfully.
    struct Normalized: Sendable, Hashable {
        public let title: String?
        public let body: String

        public init(title: String?, body: String) {
            self.title = title
            self.body = body
        }
    }

    /// Cleans the dirty GFM the Apple-docs crawler emits into well-formed GFM, so
    /// swift-markdown renders real headings, code blocks, lists, and links. It strips the
    /// frontmatter, the `| Apple Developer Documentation` title suffix, the breadcrumb
    /// list, and the `Kind# Title` run-on; lifts the run-on availability string onto its
    /// own line of monospaced chips; inserts the blank lines that mid-line `##` headings
    /// and run-on link lists need; and tags untagged code fences as Swift. Prose
    /// transforms run only outside fenced code, so source is never rewritten.
    enum Normalizer {
        public static func normalize(_ raw: String, title fallbackTitle: String? = nil) -> Normalized {
            var text = stripFrontmatter(raw)
            var title = fallbackTitle
            (title, text) = liftTitle(text, fallback: fallbackTitle)
            text = lineWalk(text)
            text = mapProse(text) { prose in
                var cleaned = prose
                cleaned = splitAvailability(cleaned)
                cleaned = splitRunOnHeadings(cleaned)
                cleaned = splitRunOnLinkLists(cleaned)
                return cleaned
            }
            text = collapseBlankLines(text)
            return Normalized(title: title?.strippingDocsSuffix, body: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // MARK: Frontmatter

        private static func stripFrontmatter(_ text: String) -> String {
            guard text.hasPrefix("---\n") else { return text }
            let afterOpen = text.index(text.startIndex, offsetBy: 4)
            guard let close = text.range(of: "\n---\n", range: afterOpen ..< text.endIndex)
                ?? text.range(of: "\n---", range: afterOpen ..< text.endIndex)
            else { return text }
            return String(text[close.upperBound...])
        }

        // MARK: Title

        /// Pull the leading `# Title` out of the body (the reader shows it as a header) and
        /// strip the site suffix. Falls back to the passed-in title if there is no H1.
        private static func liftTitle(_ text: String, fallback: String?) -> (String?, String) {
            var lines = text.components(separatedBy: "\n")
            guard let index = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
                return (fallback, text)
            }
            let first = lines[index].trimmingCharacters(in: .whitespaces)
            guard first.hasPrefix("# ") else { return (fallback, text) }
            let title = String(first.dropFirst(2)).strippingDocsSuffix
            lines.remove(at: index)
            return (title, lines.joined(separator: "\n"))
        }

        // MARK: Line walk (breadcrumbs, kind run-on, fence tagging)

        private static let kindPrefixes = [
            "Structure", "Class", "Protocol", "Enumeration", "Actor", "Instance Property",
            "Type Property", "Instance Method", "Type Method", "Initializer", "Case",
            "Global Variable", "Function", "Macro", "Type Alias", "Operator", "Subscript",
            "Article", "Sample Code", "Framework",
        ]

        private static func lineWalk(_ text: String) -> String {
            var out: [String] = []
            var inFence = false
            var previousWasBreadcrumb = false
            for line in text.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("```") {
                    if !inFence {
                        let info = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                        out.append(info.isEmpty ? "```swift" : line)
                        inFence = true
                    } else {
                        out.append(line)
                        inFence = false
                    }
                    previousWasBreadcrumb = false
                    continue
                }
                if inFence {
                    out.append(line)
                    continue
                }
                if isBreadcrumbLink(trimmed) {
                    previousWasBreadcrumb = true
                    continue
                }
                // The trailing bare current crumb (`-  State `) right after the links.
                if previousWasBreadcrumb, trimmed.hasPrefix("- "), !trimmed.contains("[") {
                    previousWasBreadcrumb = false
                    continue
                }
                previousWasBreadcrumb = false
                if let stripped = strippingKindRunOn(trimmed), stripped.isEmpty {
                    continue
                }
                out.append(line)
            }
            return out.joined(separator: "\n")
        }

        private static func isBreadcrumbLink(_ trimmed: String) -> Bool {
            matches(trimmed, #"^-\s*\[\s*.+\s*\]\(/documentation/[^)]+\)\s*$"#)
        }

        /// A `Kind# Title` run-on line (e.g. `Structure# State`) carries no content the
        /// title and declaration do not, so it is dropped (returns empty).
        private static func strippingKindRunOn(_ trimmed: String) -> String? {
            for kind in kindPrefixes where trimmed.hasPrefix("\(kind)# ") {
                return ""
            }
            return nil
        }

        // MARK: Prose transforms (outside code fences only)

        /// Apply `transform` to the non-code segments, leaving fenced code untouched.
        private static func mapProse(_ text: String, _ transform: (String) -> String) -> String {
            var result = ""
            var inFence = false
            var buffer = ""
            func flush() {
                result += inFence ? buffer : transform(buffer)
                buffer = ""
            }
            for line in text.components(separatedBy: "\n") {
                let isFence = line.trimmingCharacters(in: .whitespaces).hasPrefix("```")
                if isFence {
                    flush()
                    result += line + "\n"
                    inFence.toggle()
                } else {
                    buffer += line + "\n"
                }
            }
            flush()
            return result
        }

        private static let platforms = "iOS|iPadOS|Mac Catalyst|macOS|tvOS|watchOS|visionOS"

        /// `…managed by SwiftUI.iOS 13.0+iPadOS 13.0+…` -> the prose, then a new line of
        /// monospaced chips `` `iOS 13.0+` `iPadOS 13.0+` `` so it renders as a badge row.
        private static func splitAvailability(_ text: String) -> String {
            let token = "(?:\(platforms)) [0-9][0-9.]*\\+"
            guard let runRegex = try? NSRegularExpression(pattern: "(\(token))+"),
                  let tokenRegex = try? NSRegularExpression(pattern: token)
            else { return text }
            let nsText = text as NSString
            var result = text
            // Work over matches back-to-front so earlier ranges stay valid.
            let runs = runRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for run in runs.reversed() where run.range.length > 6 {
                let runText = nsText.substring(with: run.range)
                let chips = tokenRegex.matches(in: runText, range: NSRange(location: 0, length: (runText as NSString).length))
                    .map { "`" + (runText as NSString).substring(with: $0.range) + "`" }
                guard chips.count >= 2 else { continue }
                let replacement = "\n\n" + chips.joined(separator: " ") + "\n"
                result = (result as NSString).replacingCharacters(in: run.range, with: replacement)
            }
            return result
        }

        /// Insert a blank line before a `##`/`###` heading glued to the end of the
        /// previous line (e.g. `…](url)## [Overview](url)`), so it parses as a heading.
        private static func splitRunOnHeadings(_ text: String) -> String {
            replacing(#"([^\n])(#{2,4} )"#, with: "$1\n\n$2", in: text)
        }

        /// Break a run-on link list (`](a)[ B ](b)[ C ](c)`) so each link sits on its own
        /// line and renders as a readable list rather than one unreadable run.
        private static func splitRunOnLinkLists(_ text: String) -> String {
            replacing(#"\)\[ "#, with: ")\n[ ", in: text)
        }

        // MARK: Whitespace

        private static func collapseBlankLines(_ text: String) -> String {
            replacing(#"\n{3,}"#, with: "\n\n", in: text)
        }

        // MARK: Regex helpers

        private static func matches(_ text: String, _ pattern: String) -> Bool {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            return regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) != nil
        }

        private static func replacing(_ pattern: String, with template: String, in text: String) -> String {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
            let range = NSRange(location: 0, length: (text as NSString).length)
            return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
        }
    }
}

private extension String {
    /// Drop the crawler's `| Apple Developer Documentation` (spaced or not) title suffix.
    var strippingDocsSuffix: String {
        guard let regex = try? NSRegularExpression(pattern: #"\s*\|\s*Apple ?Developer ?Documentation\s*$"#, options: [.caseInsensitive]) else {
            return self
        }
        let range = NSRange(location: 0, length: (self as NSString).length)
        return regex.stringByReplacingMatches(in: self, range: range, withTemplate: "").trimmingCharacters(in: .whitespaces)
    }
}
