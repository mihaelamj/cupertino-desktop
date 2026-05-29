# App Colors Architecture Rules

Color-system rules for the planned Tiledown native editor. Build the colors package with HSV-based color management, dynamic light/dark support, and semantic naming. The colors package is independent from the theme package, which combines colors + fonts.

## Core rules

### Rule 1: Package structure

Structure the design system as separate packages:

- **AppColors**: standalone color system (zero dependencies)
- **AppFont**: standalone font system (zero dependencies)
- **AppTheme**: combines AppColors + AppFont

### Rule 2: HSV internal representation

Use HSV (Hue, Saturation, Value) internally:

- Store all colors as HSV components.
- Calculate dark/light variants by HSV manipulation.
- Convert to/from RGB only when handing a SwiftUI `Color` to the UI.

### Rule 3: Semantic color names (Apple HIG)

Use these exact semantic names:

- `primary`: primary brand/action color (like systemBlue)
- `success`: success states (like systemGreen)
- `secondary`: secondary brand color (like systemPurple)
- `destructive`: destructive/error actions (like systemRed). Apple uses "destructive", NOT "danger".
- `label`: primary text color (like `UIColor.label`)
- `secondaryLabel`: secondary text color
- `onPrimary`: text on primary-colored backgrounds
- `background`: primary background (like systemBackground)
- `secondaryBackground`: secondary/elevated background

### Rule 4: Dynamic color support

Create dynamic colors that adapt to appearance:

- Use `UIColor` dynamic colors on iOS.
- Use `NSColor` dynamic colors on macOS.
- Fall back to the light variant on other platforms.

### Rule 5: Initialization modes

Support two initialization modes:

1. **Explicit colors**: caller provides light and dark variants.
2. **System fallback**: use system colors as defaults.

## Package hierarchy

```
AppColors (standalone - zero dependencies)
    ↓
AppFont (standalone - zero dependencies)
    ↓
AppTheme (combines AppColors + AppFont)
```

### AppColors package structure

```
Sources/AppColors/
├── HSVColor.swift              # HSV color representation
├── Color+Dynamic.swift         # Dynamic color extension
├── Color+HSV.swift             # HSV conversion utilities
├── AppColors.swift             # Main semantic colors
└── SystemColorDefaults.swift   # System color fallbacks
```

### Package.swift configuration

```swift
let appColorsTarget = Target.target(
    name: "AppColors",
    dependencies: []  // Foundation layer; zero dependencies
)

let appFontTarget = Target.target(
    name: "AppFont",
    dependencies: [],
    resources: [.process("Fonts")]
)

let appThemeTarget = Target.target(
    name: "AppTheme",
    dependencies: [
        "AppColors",
        "AppFont",
    ]
)
```

## Implementation patterns

### 1. HSV color representation

```swift
import SwiftUI

/// Internal HSV color representation for manipulation.
public struct HSVColor: Equatable, Sendable {
    public let hue: Double        // 0.0 - 1.0
    public let saturation: Double // 0.0 - 1.0
    public let value: Double      // 0.0 - 1.0
    public let alpha: Double      // 0.0 - 1.0

    public init(hue: Double, saturation: Double, value: Double, alpha: Double = 1.0) {
        self.hue = hue
        self.saturation = saturation
        self.value = value
        self.alpha = alpha
    }

    public func toColor() -> Color {
        Color(hue: hue, saturation: saturation, brightness: value, opacity: alpha)
    }

    /// Dark variant: reduce brightness, slightly increase saturation.
    public func darkVariant() -> HSVColor {
        HSVColor(
            hue: hue,
            saturation: min(1.0, saturation * 1.1),
            value: max(0.15, value * 0.6),
            alpha: alpha
        )
    }

    /// Light variant: increase brightness, slightly reduce saturation.
    public func lightVariant() -> HSVColor {
        HSVColor(
            hue: hue,
            saturation: max(0.0, saturation * 0.85),
            value: min(1.0, value * 1.3),
            alpha: alpha
        )
    }

    public func adjustingValue(by factor: Double) -> HSVColor {
        HSVColor(hue: hue, saturation: saturation, value: min(1.0, max(0.0, value * factor)), alpha: alpha)
    }

    public func adjustingSaturation(by factor: Double) -> HSVColor {
        HSVColor(hue: hue, saturation: min(1.0, max(0.0, saturation * factor)), value: value, alpha: alpha)
    }
}
```

### 2. Color + HSV extension

```swift
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    public init(hsv: HSVColor) {
        self = hsv.toColor()
    }

    public func toHSV() -> HSVColor {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return HSVColor(hue: Double(hue), saturation: Double(saturation), value: Double(brightness), alpha: Double(alpha))
        #elseif canImport(AppKit)
        let nsColor = NSColor(self)
        let converted = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        converted.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return HSVColor(hue: Double(hue), saturation: Double(saturation), value: Double(brightness), alpha: Double(alpha))
        #else
        return HSVColor(hue: 0, saturation: 0, value: 0.5, alpha: 1.0)
        #endif
    }
}
```

### 3. Dynamic color extension

```swift
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    /// Creates a dynamic color that adapts to appearance.
    public init(light: Color, dark: Color) {
        #if os(iOS)
        self = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif os(macOS)
        self = Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #else
        self = light
        #endif
    }

    /// Dynamic color from HSV, auto-calculating the dark variant.
    public init(lightHSV: HSVColor) {
        self.init(light: lightHSV.toColor(), dark: lightHSV.darkVariant().toColor())
    }

    /// Dynamic color from HSV, auto-calculating the light variant.
    public init(darkHSV: HSVColor) {
        self.init(light: darkHSV.lightVariant().toColor(), dark: darkHSV.toColor())
    }
}
```

### 4. System color defaults

```swift
import SwiftUI

/// System color defaults for fallback (Apple HIG inspired).
public enum SystemColorDefaults {
    public static let primary = HSVColor(hue: 0.58, saturation: 0.8, value: 0.9)          // Blue
    public static let success = HSVColor(hue: 0.33, saturation: 0.7, value: 0.8)          // Green
    public static let secondary = HSVColor(hue: 0.75, saturation: 0.6, value: 0.85)       // Purple
    public static let destructive = HSVColor(hue: 0.0, saturation: 0.8, value: 0.9)       // Red
    public static let label = HSVColor(hue: 0.0, saturation: 0.0, value: 0.1)             // Near-black
    public static let secondaryLabel = HSVColor(hue: 0.0, saturation: 0.0, value: 0.5)    // Medium gray
    public static let onPrimary = HSVColor(hue: 0.0, saturation: 0.0, value: 1.0)         // White
    public static let background = HSVColor(hue: 0.0, saturation: 0.0, value: 1.0)        // White
    public static let secondaryBackground = HSVColor(hue: 0.0, saturation: 0.0, value: 0.95) // Light gray
}
```

### 5. AppColors main structure

```swift
import SwiftUI

/// Semantic color palette (Apple HIG naming).
public struct AppColors: Sendable {
    // Semantic
    public let primary: Color
    public let success: Color
    public let secondary: Color
    public let destructive: Color

    // Text
    public let label: Color
    public let secondaryLabel: Color
    public let onPrimary: Color

    // Background
    public let background: Color
    public let secondaryBackground: Color

    /// Initialize with explicit HSV light-mode colors. Dark variants are calculated automatically.
    public init(
        primaryHSV: HSVColor,
        successHSV: HSVColor,
        secondaryHSV: HSVColor,
        destructiveHSV: HSVColor,
        labelHSV: HSVColor,
        secondaryLabelHSV: HSVColor,
        onPrimaryHSV: HSVColor,
        backgroundHSV: HSVColor,
        secondaryBackgroundHSV: HSVColor
    ) {
        primary = Color(lightHSV: primaryHSV)
        success = Color(lightHSV: successHSV)
        secondary = Color(lightHSV: secondaryHSV)
        destructive = Color(lightHSV: destructiveHSV)
        label = Color(lightHSV: labelHSV)
        secondaryLabel = Color(lightHSV: secondaryLabelHSV)
        onPrimary = Color(lightHSV: onPrimaryHSV)
        background = Color(lightHSV: backgroundHSV)
        secondaryBackground = Color(lightHSV: secondaryBackgroundHSV)
    }

    /// Initialize with explicit light/dark Color pairs.
    public init(
        primary: (light: Color, dark: Color),
        success: (light: Color, dark: Color),
        secondary: (light: Color, dark: Color),
        destructive: (light: Color, dark: Color),
        label: (light: Color, dark: Color),
        secondaryLabel: (light: Color, dark: Color),
        onPrimary: (light: Color, dark: Color),
        background: (light: Color, dark: Color),
        secondaryBackground: (light: Color, dark: Color)
    ) {
        self.primary = Color(light: primary.light, dark: primary.dark)
        self.success = Color(light: success.light, dark: success.dark)
        self.secondary = Color(light: secondary.light, dark: secondary.dark)
        self.destructive = Color(light: destructive.light, dark: destructive.dark)
        self.label = Color(light: label.light, dark: label.dark)
        self.secondaryLabel = Color(light: secondaryLabel.light, dark: secondaryLabel.dark)
        self.onPrimary = Color(light: onPrimary.light, dark: onPrimary.dark)
        self.background = Color(light: background.light, dark: background.dark)
        self.secondaryBackground = Color(light: secondaryBackground.light, dark: secondaryBackground.dark)
    }

    /// Default palette using system colors.
    public static let system = AppColors(
        primaryHSV: SystemColorDefaults.primary,
        successHSV: SystemColorDefaults.success,
        secondaryHSV: SystemColorDefaults.secondary,
        destructiveHSV: SystemColorDefaults.destructive,
        labelHSV: SystemColorDefaults.label,
        secondaryLabelHSV: SystemColorDefaults.secondaryLabel,
        onPrimaryHSV: SystemColorDefaults.onPrimary,
        backgroundHSV: SystemColorDefaults.background,
        secondaryBackgroundHSV: SystemColorDefaults.secondaryBackground
    )
}

// MARK: - Environment

private struct AppColorsKey: EnvironmentKey {
    static let defaultValue = AppColors.system
}

extension EnvironmentValues {
    public var appColors: AppColors {
        get { self[AppColorsKey.self] }
        set { self[AppColorsKey.self] = newValue }
    }
}

extension View {
    public func appColors(_ colors: AppColors) -> some View {
        environment(\.appColors, colors)
    }
}
```

### 6. AppTheme package (combines colors + fonts)

```swift
import SwiftUI
import AppColors
import AppFont

/// Complete theme combining colors and typography.
public struct AppTheme: Sendable {
    public let colors: AppColors

    public init(colors: AppColors = .system) {
        self.colors = colors
    }

    public static let system = AppTheme(colors: .system)
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.system
}

extension EnvironmentValues {
    public var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

extension View {
    public func appTheme(_ theme: AppTheme) -> some View {
        environment(\.appTheme, theme)
    }
}
```

## Usage patterns

### Basic usage with system colors

```swift
import SwiftUI
import AppColors

struct MyView: View {
    @Environment(\.appColors) var colors

    var body: some View {
        VStack {
            Text("Primary Text")
                .foregroundColor(colors.label)

            Button("Action") {}
                .foregroundColor(colors.onPrimary)
                .background(colors.primary)
        }
        .background(colors.background)
    }
}
```

### Custom brand colors

```swift
let customColors = AppColors(
    primaryHSV: HSVColor(hue: 0.6, saturation: 0.85, value: 0.95),
    successHSV: HSVColor(hue: 0.33, saturation: 0.7, value: 0.8),
    secondaryHSV: HSVColor(hue: 0.75, saturation: 0.6, value: 0.85),
    destructiveHSV: HSVColor(hue: 0.0, saturation: 0.8, value: 0.9),
    labelHSV: HSVColor(hue: 0, saturation: 0, value: 0.1),
    secondaryLabelHSV: HSVColor(hue: 0, saturation: 0, value: 0.5),
    onPrimaryHSV: HSVColor(hue: 0, saturation: 0, value: 1.0),
    backgroundHSV: HSVColor(hue: 0, saturation: 0, value: 1.0),
    secondaryBackgroundHSV: HSVColor(hue: 0, saturation: 0, value: 0.95)
)

@main
struct TiledownApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .appColors(customColors)
        }
    }
}
```

## Common mistakes

- Making `AppColors` depend on `AppFont` (it MUST be standalone).
- Storing colors as RGB internally instead of HSV.
- Hardcoding dark-mode colors instead of calculating them from HSV.
- Static colors that do not adapt to dark mode.
- Non-semantic names like `blue`, `red`, `lightGray`.
- Material Design naming (`error`, `surface`, `onSurface`). Use Apple HIG: `destructive`, `background`, `label`.

## Checklist

- [ ] `AppColors` is a standalone package (zero dependencies)
- [ ] `AppFont` is a standalone package (zero dependencies)
- [ ] `AppTheme` combines `AppColors` + `AppFont`
- [ ] `HSVColor` defined with hue, saturation, value, alpha
- [ ] `HSVColor` has `darkVariant()` and `lightVariant()`
- [ ] `Color+Dynamic` implements `init(light:dark:)`
- [ ] `Color+HSV` converts between `Color` and `HSVColor`
- [ ] All 9 semantic colors present, Apple HIG naming
- [ ] Used `destructive` (not "danger"/"error")
- [ ] Used `label`/`secondaryLabel` (not "textPrimary")
- [ ] Used `background`/`secondaryBackground` (not "bgPrimary")
- [ ] `SystemColorDefaults` provides fallback values
- [ ] `AppColors.system` static property exists
- [ ] Environment keys for `appColors` and `appTheme`
- [ ] Platform-specific dynamic colors (`#if os(iOS)` / `os(macOS)`)
