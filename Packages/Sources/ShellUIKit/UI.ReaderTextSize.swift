import AppCore
import AppModels

#if canImport(UIKit)
    import UIKit

    extension UI {
        /// Builds the reader's text-size bar buttons over the shared `Model.ReaderTextSize`
        /// store. macOS has no Dynamic Type, so this manual +/- control is the resize
        /// mechanism on the Mac and an extra on iOS; the base size still comes from the
        /// platform's semantic body font.
        enum ReaderTextSize {
            @MainActor
            static func barButtonItems(target: AnyObject, larger: Selector, smaller: Selector) -> [UIBarButtonItem] {
                let increase = UIBarButtonItem(image: UIImage(systemName: "textformat.size.larger"), style: .plain, target: target, action: larger)
                let decrease = UIBarButtonItem(image: UIImage(systemName: "textformat.size.smaller"), style: .plain, target: target, action: smaller)
                increase.accessibilityIdentifier = UI.AccessibilityID.Reader.textLarger
                decrease.accessibilityIdentifier = UI.AccessibilityID.Reader.textSmaller
                increase.isEnabled = Model.ReaderTextSize.canIncrease
                decrease.isEnabled = Model.ReaderTextSize.canDecrease
                return [increase, decrease]
            }
        }
    }
#endif
