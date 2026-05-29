# SwiftUI View Rules

SwiftUI view rules for the planned Tiledown native editor: purely presentational, performant, accessible, reusable. Views observe ViewModels but contain ZERO business logic.

## Core rules

1. Views render ViewModel state only: no business logic, no API calls
2. Use `@State` for view-local UI state, `@Bindable` for ViewModel bindings
3. Use lazy containers for lists >50 items
4. Every interactive element requires an accessibility label
5. Extract components used 1+ times
6. Import a hot-reload helper and add the hot-reload observation property for live previews during development
7. Use case-pathable enums for navigation state

## Decision tree: code belongs in View?

```
Visual presentation → YES
UI animation → YES
Local UI state → YES (@State)
Data transformation → NO (ViewModel)
Business logic → NO (ViewModel/Service)
Navigation → View binds to ViewModel destination
```

## Patterns

### Pure presentation

```swift
// CORRECT
struct TilePreviewView: View {
    let tile: Tile
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack {
                Text(tile.name)
                Text(tile.sizeDescription)
            }
        }
    }
}

// INCORRECT: View with business logic
struct BadTileView: View {
    let tile: Tile

    var body: some View {
        Button("Render") {
            // Wrong: direct service call in view
            Task {
                try? await RenderService.shared.render(tile)
            }
        }
    }
}
```

### ViewModel integration

```swift
// Container gets injected ViewModel
struct TileListScreen: View {
    @Bindable var viewModel: TileListViewModel

    var body: some View {
        TileListView(viewModel: viewModel)
            .task { await viewModel.onViewAppear() }
    }
}

// Inner view receives ViewModel
struct TileListView: View {
    let viewModel: TileListViewModel

    var body: some View {
        List(viewModel.tiles) { tile in
            Button { viewModel.onUserSelected(tile) } label: {
                Text(tile.name)
            }
        }
    }
}
```

### Reusable component

```swift
// ViewBuilder slot
struct AsyncButton<Label: View>: View {
    let action: () async -> Void
    @ViewBuilder let label: () -> Label
    @State private var isLoading = false

    var body: some View {
        Button {
            Task {
                isLoading = true
                await action()
                isLoading = false
            }
        } label: {
            isLoading ? ProgressView() : label()
        }
        .disabled(isLoading)
    }
}

// ViewModifier
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
    }
}
```

### Accessibility

```swift
TextField("Name", text: $name)
    .accessibilityLabel("Your name")
    .accessibilityHint("Required field")

Button("Submit", action: onSubmit)
    .accessibilityHint("Double tap to save")
```

### Navigation

```swift
// Define destinations using @CasePathable
@CasePathable
enum Destination {
    case detail(DetailFeature)
    case settings(SettingsFeature)
    case alert(AlertState<AlertAction>)
}

@Observable @MainActor
final class AppViewModel {
    var destination: Destination?

    func onTappedItem(id: String) {
        destination = .detail(DetailFeature(id: id))
    }

    func onTappedSettings() {
        destination = .settings(SettingsFeature())
    }
}

struct AppView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        List {
            Button("Show Detail") { viewModel.onTappedItem(id: "123") }
            Button("Settings") { viewModel.onTappedSettings() }
        }
        .navigationDestination(item: $viewModel.destination.detail) { feature in
            DetailView(viewModel: feature)
        }
        .navigationDestination(item: $viewModel.destination.settings) { feature in
            SettingsView(viewModel: feature)
        }
        .alert($viewModel.destination.alert) { action in
            viewModel.onAlertAction(action)
        }
    }
}
```

### Sheets and covers

```swift
@CasePathable
enum Destination {
    case editSheet(EditFeature)
    case detailCover(DetailFeature)
    case confirmationAlert(AlertState<ConfirmAction>)
}

@Observable @MainActor
final class FeatureViewModel {
    var destination: Destination?

    func onTappedEdit() {
        destination = .editSheet(EditFeature())
    }

    func onTappedDetail() {
        destination = .detailCover(DetailFeature())
    }
}

struct FeatureView: View {
    @Bindable var viewModel: FeatureViewModel

    var body: some View {
        List {
            Button("Edit") { viewModel.onTappedEdit() }
            Button("Detail") { viewModel.onTappedDetail() }
        }
        .sheet(item: $viewModel.destination.editSheet) { feature in
            EditView(viewModel: feature)
        }
        .fullScreenCover(item: $viewModel.destination.detailCover) { feature in
            DetailView(viewModel: feature)
        }
        .alert($viewModel.destination.confirmationAlert) { action in
            viewModel.onConfirmAction(action)
        }
    }
}
```

## Validation checklist

- [ ] Zero business logic
- [ ] Actions forwarded to ViewModel
- [ ] Accessibility labels provided
- [ ] Performance optimized (lazy loading)
- [ ] Components extracted for reuse
- [ ] Navigation uses case-pathable destinations
- [ ] Error/loading/empty states handled

## Identity and conditional views

SwiftUI view identity is fragile. Whenever you switch entire view branches with `if/else`, you create different view identities and risk losing any `@State` attached to them.

### Prefer null views and stable containers

Bad (two different branches = two identities):

```swift
if hasSelection {
    DetailView(item: selected)
} else {
    ContentUnavailableView {
        Label("No Selection", systemImage: "sidebar.left")
    } description: {
        Text("Select an item from the sidebar to view its details")
    }
}
```

Instead, prefer a stable container with conditional content:

```swift
ZStack {
    if let item = selected {
        DetailView(item: item)
    } else {
        ContentUnavailableView {
            Label("No Selection", systemImage: "sidebar.left")
        } description: {
            Text("Select an item from the sidebar to view its details")
        }
    }
}
```

Or keep the same view and vary styling with a null/no-op modifier:

```swift
ViewWithState()
    .background(flag ? .red : .clear)
    .animation(.easeInOut(duration: 2), value: flag)
```

Closures must never participate in identity.

Rules of thumb:

- Views with local `@State` MUST keep a stable identity.
- Containers without state MAY switch child content.
- When only styling changes, use parameters or no-op modifiers (like `.background(.clear)`), instead of duplicating view branches.
