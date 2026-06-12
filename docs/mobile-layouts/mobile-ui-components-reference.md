# Reference: Mobile UI Components Behavior and Styling

**Status:** Accepted.
**Date:** 2026-06-12.
**Anchors:** [mobile-orientation-adaptivity-matrix.md](mobile-orientation-adaptivity-matrix.md), [fixed-native-ui-matrix.md](../decisions/fixed-native-ui-matrix.md).

This document details how each core UI component in the Cupertino mobile applications (both SwiftUI and UIKit implementations) acts and looks in different size classes, orientations, and device configurations.

---

## 1. Database Source List (Root Sidebar)
*The entry point of the app, presenting the available documentation databases (Apple Docs, HIG, Swift Evolution, etc.).*

### Compact Environment (iPhone / iPad Multitasking)
* **Visual Presentation**: Full-screen table (`UITableView` in UIKit, `List` in SwiftUI) with standard cell rows.
* **Component Styling**: Inset grouped style, utilizing system icons (SF Symbols) and accessory chevron disclosures (`.disclosureIndicator` in UIKit, native `NavigationLink` indicators in SwiftUI).
* **Navigation / Action**: Tapping a row pushes the corresponding **Frameworks List** onto the navigation stack (`navigationController?.pushViewController(...)` or SwiftUI navigation path append).
* **Selection State**: Transient. Upon returning to this screen via the navigation back button, the selected row's highlight animatedly fades out (`deselectRow(at:animated:)`).

### Regular Environment (iPad Full Screen / Mac)
* **Visual Presentation**: The leading sidebar column of a multi-stage layout (`UISplitViewController` primary column / `NavigationSplitView` sidebar).
* **Component Styling**: Clean sidebar style, flush with the screen edges, using standard sidebar lists (`SidebarListStyle` / inset grouped table).
* **Navigation / Action**: Selecting a source updates the secondary column in-place with the matching frameworks.
* **Selection State**: Persistent. The active database row remains highlighted as the user interacts with child columns.

---

## 2. Frameworks List (Secondary Sidebar / Column)
*Displays the list of frameworks/modules within the selected database (e.g., SwiftUI, UIKit, Foundation).*

### Compact Environment (iPhone / iPad Multitasking)
* **Visual Presentation**: Full-screen list.
* **Header / Navigation Bar**: Standard navigation bar containing the database display name (e.g., "Apple Docs"), a right bar button for sorting, and an integrated search bar.
* **Navigation / Action**: Selecting a framework row pushes the **Documents List** or **Selection Detail View** onto the navigation stack.
* **Selection State**: Transient. Deselects automatically on return to match standard iOS push-navigation conventions.

### Regular Environment (iPad Full Screen / Mac)
* **Visual Presentation**: Renders as the secondary sidebar column of the split view.
* **Header / Navigation Bar**: Search field and sorting menu are positioned persistently at the top of the sidebar. In SwiftUI, this uses a custom vertical stack header to avoid polluting the main window toolbar.
* **Navigation / Action**: Selecting a framework updates the main detail pane in-place to display that framework's documents.
* **Selection State**: Persistent. The selected framework row remains highlighted while the user reads the documents in the detail column.

---

## 3. Search Bar / Field
*Allows filtering frameworks and global document searches.*

### Compact Environment (iPhone / iPad Multitasking)
* **Visual Presentation**: Standard search controller (`UISearchController` in UIKit) embedded in the navigation bar (`navigationItem.searchController`), or a SwiftUI `.searchable` text field.
* **Interaction**: Collapses on scroll to maximize reading space. Tapping focuses the text field, showing the keyboard and the system "Cancel" button.
* **Testability / Accessibility**: Maps to `XCUIApplication().searchFields.firstMatch` or `textFields.firstMatch` in automation.

### Regular Environment (iPad Full Screen / Mac)
* **Visual Presentation**: A persistent, static search text field embedded directly at the top of the sidebar list.
* **Interaction**: Always visible, does not scroll out of view. In macOS AppKit, it immediately receives first responder focus on screen load so users can start typing without mouse clicks.
* **Testability / Accessibility**: Unified text field class identifier is used across both orientations to guarantee reliable test lookup.

---

## 4. Document Reader (Detail View)
*Renders the rich markdown body of the selected document.*

### Compact Environment (iPhone / iPhone Landscape / iPad Multitasking)
* **Visual Presentation**: Full-screen reader.
* **Header / Controls**: Back button in the top-left to return to the documents list. Text sizing buttons (A+ / A-) are placed in the bottom navigation toolbar or top navigation bar.
* **Ergonomics**: Optimized for one-handed thumb reading. Preserved margins and paragraph spacing prevent content from extending under bezel cutouts.

### Regular Environment (iPad Full Screen / Mac)
* **Visual Presentation**: Side-by-side pane alongside the sidebar.
* **Header / Controls**: Top-right toolbar contains text resizing controls and the share actions. No back button is present (selection is changed in-place by tapping other sidebar rows).
* **Ergonomics**: Wide layout with centered readable body width (max line width of 700-800pt) to prevent eye strain on large screens.

---

## 5. Sort Button / Menu
*Sorts frameworks alphabetically or by document count.*

### Compact Environment (iPhone / iPad Multitasking)
* **Visual Presentation**: A simple navigation bar button item (`UIBarButtonItem` in UIKit) in the top-right.
* **Interaction**: Tapping opens a bottom action sheet or a context menu overlay containing the sorting options ("Sort by Name", "Sort by Count").

### Regular Environment (iPad Full Screen / Mac)
* **Visual Presentation**: A persistent icon button placed horizontally adjacent to the search field in the sidebar header.
* **Interaction**: Tapping opens a dropdown menu (`UIMenu` / SwiftUI `Menu`).

---

## 6. Selection Highlight and State Transitions

| Component | State / Event | Compact (iPhone / Narrow iPad) | Regular (iPad / Mac) |
| :--- | :--- | :--- | :--- |
| **Row Selection** | Selected | Pushes view controller / navigates path | Retains selection, updates detail view in-place |
| **Row Selection** | Returned to | Row animates to deselected state | Row remains persistently highlighted |
| **Search State** | Text cleared | Resets list, returns focus | Resets list, retains focus in header |
| **Orientation Change** | Rotate to Landscape | Stays single-column (forces compact) | Adapts to side-by-side split view |
| **Orientation Change** | Rotate to Portrait | Stays single-column | Adapts to side-by-side split view |
