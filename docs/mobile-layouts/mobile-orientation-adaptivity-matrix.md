# Decision: Mobile Orientation and Size Class Adaptivity Matrix

**Status:** Accepted.
**Date:** 2026-06-12.
**Supersedes:** Any previous layout behavior where iPhone in landscape orientation would render a two-column split view (e.g., standard SwiftUI NavigationSplitView or UIKit UISplitViewController on Max/Plus models).
**Anchors:** [fixed-native-ui-matrix.md](../decisions/fixed-native-ui-matrix.md), [MOBILE.md](../MOBILE.md), [UI-DESIGN.md](../UI-DESIGN.md).

## Context

According to the Apple Human Interface Guidelines (HIG):
1. **iPhone** is inherently a compact, one-handed device. Side-by-side split screen columns (even on larger models like Max or Plus in landscape that natively support a regular width size class) result in cramped visual hierarchies, clipped text, and require two hands to operate.
2. **iPad** represents a desktop-class multitasking environment matching macOS expectations. In full screen, it should display multiple panes side-by-side (Regular × Regular). In multitasking split-screen or slide-over states, it resizes down to compact widths where it should collapse cleanly to single-column navigation.

We need a deterministic layout mapping for all device classes, orientations, window states, and size classes to ensure HIG compliance.

## Decision

We separate the visual layout and size class treatment of iPhone, iPad, and macOS, overriding native size classes where necessary to enforce consistent one-handed usage on iPhone and side-by-side productivity on iPad/macOS.

### 1. Complete Layout Matrix

| Platform / Device | Orientation / Window State | Native Size Class (H × V) | Effective size Class in Cupertino | Visual Layout | Navigation Style | Sidebar Selection Style |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **iPhone** (Standard / SE / mini) | Portrait | **Compact × Regular** | **Compact × Regular** | Single-column | Navigation Stack (push / pop) | Transient (deselects on return) |
| **iPhone** (Standard / SE / mini) | Landscape | **Compact × Compact** | **Compact × Compact** | Single-column | Navigation Stack (push / pop) | Transient (deselects on return) |
| **iPhone** (Max / Plus / Pro Max) | Portrait | **Compact × Regular** | **Compact × Regular** | Single-column | Navigation Stack (push / pop) | Transient (deselects on return) |
| **iPhone** (Max / Plus / Pro Max) | Landscape | **Regular × Compact** | **Compact × Compact** (Forced) | Single-column | Navigation Stack (push / pop) | Transient (deselects on return) |
| **iPad** (All models) | Full Screen Portrait | **Regular × Regular** | **Regular × Regular** | Two-column split | Split View (sidebar + detail) | Persistent (highlighted) |
| **iPad** (All models) | Full Screen Landscape | **Regular × Regular** | **Regular × Regular** | Two-column split | Split View (sidebar + detail) | Persistent (highlighted) |
| **iPad** (Multitasking) | Slide Over / 1/3 Split (Narrow) | **Compact × Regular** | **Compact × Regular** | Single-column | Navigation Stack (push / pop) | Transient (deselects on return) |
| **iPad** (Multitasking) | 1/2 Split Landscape (Narrow) | **Compact × Regular** | **Compact × Regular** | Single-column | Navigation Stack (push / pop) | Transient (deselects on return) |
| **macOS** (AppKit / SwiftUI) | Windowed | **Regular × Regular** | **Regular × Regular** | Two-column split | Split View (sidebar + detail) | Persistent (highlighted) |
| **macOS** (AppKit / SwiftUI) | Narrow Window | **Compact × Regular** (simulated) | **Regular × Regular** (Forced) | Two-column split | Split View (sidebar + detail) | Persistent (highlighted) |

### 2. Implementation details

* **SwiftUI (`UI.RootView.swift`)**:
  On iOS, we explicitly check `UIDevice.current.userInterfaceIdiom`. If the device is not an iPad, we override the horizontal size class to `.compact` regardless of the native value:
  ```swift
  private var activeHorizontalSizeClass: UserInterfaceSizeClass? {
      #if os(iOS)
          if UIDevice.current.userInterfaceIdiom == .pad {
              return horizontalSizeClass
          } else {
              return .compact
          }
      #else
          if verticalSizeClass == .compact {
              return .regular
          }
          return horizontalSizeClass
      #endif
  }
  ```

* **UIKit (`UI.RootViewController.swift`)**:
  We override `traitCollection` to force a compact size class on iPhone, ensuring the native split controller collapses into a single navigation column, while preserving the regular size class override in iPad landscape. We guard with `isViewLoaded` to prevent recursive load loops:
  ```swift
  override public var traitCollection: UITraitCollection {
      if UIDevice.current.userInterfaceIdiom == .pad {
          if isViewLoaded, view.bounds.width > view.bounds.height {
              return UITraitCollection(traitsFrom: [
                  super.traitCollection,
                  UITraitCollection(horizontalSizeClass: .regular),
              ])
          }
          return super.traitCollection
      } else {
          return UITraitCollection(traitsFrom: [
              super.traitCollection,
              UITraitCollection(horizontalSizeClass: .compact),
          ])
      }
  }
  ```

### 3. Critical UIKit Trait Collection Recursion Caveat
Accessing the `view` property inside a view controller's `traitCollection` getter when `isViewLoaded` is false will trigger `loadViewIfNeeded()`. However, the view layout setup and standard system setup query `traitCollection` on the view controller. This results in an infinite recursion loop:
1. `traitCollection` is requested.
2. `view` is accessed.
3. View triggers `loadViewIfNeeded()`.
4. View loading process queries the view controller's `traitCollection`.
5. `traitCollection` getter runs again and accesses `view`.
6. Infinite loop → stack overflow crash.

**Rule**: Never access the `view` property inside `traitCollection` (or any method called during the initialization and loading phases) unless you first check that `isViewLoaded` is true. If it is false, safely fall back to `super.traitCollection`.
