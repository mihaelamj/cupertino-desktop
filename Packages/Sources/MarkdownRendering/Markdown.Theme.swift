import AppModels
import Foundation

#if canImport(UIKit)
    import UIKit

    public typealias PlatformFont = UIFont
    public typealias PlatformColor = UIColor
#elseif canImport(AppKit)
    import AppKit

    public typealias PlatformFont = NSFont
    public typealias PlatformColor = NSColor
#endif

#if canImport(UIKit) || canImport(AppKit)
    public extension Markdown {
        /// Fonts and colors for the renderer, all derived from semantic text styles and
        /// dynamic system colors so rendered documents scale with Dynamic Type and adapt to
        /// light/dark automatically. Full Dynamic Type and a reader text-size control are
        /// tracked in the font-scaling issue; light/dark refinement in the appearance issue.
        struct Theme: Sendable {
            public var basePointSize: CGFloat

            public init(basePointSize: CGFloat? = nil) {
                // A comfortable reader default (macOS .body is only 13pt). Every font derives
                // from this, so the reader's text-size control scales the WHOLE document.
                self.basePointSize = basePointSize ?? max(PlatformFont.preferredFont(forTextStyle: .body).pointSize, 15)
            }

            // MARK: Fonts

            // All fonts derive from `basePointSize` so the text-size control scales body,
            // headings, and code together (previously body/headings used a fixed
            // `preferredFont`, so only code scaled and the body never changed size).

            var body: PlatformFont {
                .systemFont(ofSize: basePointSize)
            }

            var code: PlatformFont {
                // Slightly smaller than body: monospaced glyphs read larger at the same point
                // size, so matching body made code blocks look oversized.
                .monospacedSystemFont(ofSize: basePointSize * 0.92, weight: .regular)
            }

            func heading(level: Int) -> PlatformFont {
                let multiplier: CGFloat = switch level {
                case 1: 1.4
                case 2: 1.2
                case 3: 1.08
                default: 1.0
                }
                return .systemFont(ofSize: basePointSize * multiplier, weight: .semibold)
            }

            // MARK: Colors

            var text: PlatformColor {
                .label
            }

            var secondary: PlatformColor {
                .secondaryLabel
            }

            var link: PlatformColor {
                .link
            }

            var codeBackground: PlatformColor {
                #if canImport(UIKit)
                    .secondarySystemBackground
                #else
                    .quaternaryLabelColor
                #endif
            }

            /// Dynamic system colors per syntax role, so code highlighting tracks light/dark.
            func color(for role: Model.SyntaxRole) -> PlatformColor {
                switch role {
                case .keyword: .systemPink
                case .type: .systemPurple
                case .call: .systemBlue
                case .property: .systemTeal
                case .string: .systemRed
                case .number: .systemOrange
                case .comment: .secondaryLabel
                case .dotAccess: .systemBlue
                case .preprocessing: .systemBrown
                case .plain: text
                }
            }
        }
    }

    extension PlatformColor {
        #if canImport(AppKit)
            /// `.label` is `UIColor`-only; mirror it to `NSColor.labelColor` so the theme
            /// reads the same on both platforms.
            static var label: NSColor {
                .labelColor
            }

            static var secondaryLabel: NSColor {
                .secondaryLabelColor
            }

            static var link: NSColor {
                .linkColor
            }
        #endif
    }

    extension PlatformFont {
        /// The receiver with the bold trait added, on either platform.
        var boldened: PlatformFont {
            #if canImport(UIKit)
                guard let descriptor = fontDescriptor.withSymbolicTraits(fontDescriptor.symbolicTraits.union(.traitBold)) else { return self }
                return PlatformFont(descriptor: descriptor, size: pointSize)
            #else
                return NSFontManager.shared.convert(self, toHaveTrait: .boldFontMask)
            #endif
        }

        /// The receiver with the italic trait added, on either platform.
        var italicized: PlatformFont {
            #if canImport(UIKit)
                guard let descriptor = fontDescriptor.withSymbolicTraits(fontDescriptor.symbolicTraits.union(.traitItalic)) else { return self }
                return PlatformFont(descriptor: descriptor, size: pointSize)
            #else
                return NSFontManager.shared.convert(self, toHaveTrait: .italicFontMask)
            #endif
        }
    }
#endif
