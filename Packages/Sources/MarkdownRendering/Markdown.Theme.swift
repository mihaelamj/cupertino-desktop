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
                self.basePointSize = basePointSize ?? PlatformFont.preferredFont(forTextStyle: .body).pointSize
            }

            // MARK: Fonts

            var body: PlatformFont {
                .preferredFont(forTextStyle: .body)
            }

            var code: PlatformFont {
                .monospacedSystemFont(ofSize: basePointSize, weight: .regular)
            }

            func heading(level: Int) -> PlatformFont {
                let style: PlatformFont.TextStyle = switch level {
                case 1: .title1
                case 2: .title2
                case 3: .title3
                default: .headline
                }
                return .preferredFont(forTextStyle: style)
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
