# Actions Taken: Mobile Adaptivity Refactoring and Documentation

This document records the exact steps and engineering actions taken to implement the adaptive device orientation behaviors and document them in the repository.

---

## 1. Research & Analysis
We queried the local Human Interface Guidelines FTS5 search index (`hig.db`) using Cupertino's CLI tool to align the implementation with Apple's official design specifications:
* **Search Queries**: Searched for `"split view"`, `"sidebar"`, `"orientation"`, and `"size class"` terms.
* **Document Extraction**: Read and analyzed the full contents of:
  * `hig://general/split-views` (Platform considerations for compact vs. regular environments).
  * `hig://general/layout` (Device size classes mapping for standard/Max iPhones and iPads).
* **Key Findings**:
  * iPhone should remain a compact single-column navigation hierarchy to ensure ergonomic one-handed use, avoiding cropped two-column layouts in landscape.
  * iPad must support split screen layout in full screen but collapse to a single-column stack under narrow multitasking states (Slide Over or 1/3 split).

---

## 2. Code Refactoring (App Shells)
We updated the mobile shell implementations in the shared SPM package targets to align with these findings:

### A. UIKit Shell (`UI.RootViewController.swift`)
* Updated the `traitCollection` override to check `UIDevice.current.userInterfaceIdiom`.
* **iPhone**: Forces `horizontalSizeClass == .compact` under both portrait and landscape orientations, causing the `UISplitViewController` to collapse natively.
* **iPad**: Checks the bounds orientation (`width > height`) and overrides it to `.regular` in landscape. We added an `isViewLoaded` guard before accessing `view.bounds` to prevent an infinite recursion view-loading loop (and subsequent crash) on iPad during startup.

### B. SwiftUI Shell (`UI.RootView.swift`)
* Modified the `activeHorizontalSizeClass` computed property.
* **iPhone**: If `userInterfaceIdiom == .phone`, returns `.compact` to force the `compactView` layout (`NavigationStack`), even on larger Max or Plus models that natively report a regular width in landscape.
* **iPad**: Returns the natural system `horizontalSizeClass` to support adaptive multitasking transitions.

### C. SwiftUI Search Field (`UI.SidebarFrameworksListView.swift`)
* Unified the search field rendering to use a standard `TextField` placed inline within the sidebar on iOS.
* This resolved accessibility element tree mismatch issues in XCUITest during device rotation transitions.

---

## 3. UI Automation Verification
We ran the UI automation test suite using `xcodebuild` across multiple simulator profiles to proactively identify layout and runtime regressions:
* **Standard iPhone 17**: SwiftUI (5/5 tests) and UIKit (1/1 tests) passed successfully.
* **iPhone 17 Pro Max**: SwiftUI (1/1 tests) and UIKit (1/1 tests) passed successfully, verifying that the forced compact layout resolves correctly on large iPhones.
* **iPad Pro 13-inch (M5)**: Verified native split-view behavior. An initial run caught a stack overflow crash due to `view.bounds` access inside the `traitCollection` getter during the view loading phase. Applying the `isViewLoaded` guard resolved the regression, and both SwiftUI (1/1 tests) and UIKit (1/1 tests) now pass successfully on iPad.

---

## 4. Documentation & Indexing
To preserve these design conventions for references:
1. Created the `docs/mobile-layouts/` folder.
2. Written [mobile-orientation-adaptivity-matrix.md](mobile-orientation-adaptivity-matrix.md) describing the device orientations layout mapping.
3. Written [mobile-ui-components-reference.md](mobile-ui-components-reference.md) detailing individual visual component adaptations.
4. Added the folder's [README.md](README.md) as a navigation index.
5. Removed the temporary files from `docs/decisions/` and updated `docs/decisions/README.md`.
6. Documented the new forced compact landscape orientation behavior for Max/Plus iPhones in the main UI design specifications file [docs/UI-DESIGN.md](../UI-DESIGN.md).
