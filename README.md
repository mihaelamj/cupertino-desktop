# Cupertino Desktop

Native macOS desktop app for browsing Apple Developer documentation, Swift Evolution proposals, and sample code offline. Provides a graphical interface for Cupertino using MCPClient. Built with SwiftUI/AppKit.

## Overview

Cupertino Desktop is a native macOS application that provides a graphical interface for browsing Apple's developer documentation offline. It connects to the [Cupertino](https://github.com/mihaelamj/cupertino) MCP server via the MCPClient library, providing a native UI for all documentation features without reimplementing the search and storage layers.

## Features

- 🔍 **Fast Full-Text Search** - Search across 22,000+ documentation pages
- 📚 **Framework Browser** - Browse 261 frameworks (SwiftUI, UIKit, AppKit, Foundation, etc.)
- 📖 **Documentation Reader** - Read documentation with native rendering
- 🎯 **Sample Code Browser** - Browse and view Apple sample code with syntax highlighting
- ⚡ **Offline-First** - Works completely offline once documentation is downloaded
- 🎨 **Native macOS Interface** - Built with SwiftUI and AppKit

## UI Implementation

This project will include **both AppKit and SwiftUI** implementations:

- **AppKit version** - More control, better for complex document viewers
- **SwiftUI version** - Modern, reactive, less code

The final UI framework decision will be made after testing both approaches. Both versions will use the same MCPClient backend.

## Architecture

```
┌─────────────────────────┐
│  Desktop App            │
│                         │
│  ┌────────────────┐    │
│  │ AppKit/SwiftUI │    │  ← UI Layer (both versions)
│  └────────┬───────┘    │
│           ↓             │
│  ┌────────────────┐    │
│  │  MCPClient     │    │  ← From cupertino package
│  └────────┬───────┘    │
│           ↓             │
│  ┌────────────────┐    │
│  │cupertino serve │    │  ← Spawned subprocess
│  └────────────────┘    │
└─────────────────────────┘
```

## Requirements

- macOS 15+ (Sequoia)
- Swift 6.2+
- Xcode 16.0+
- [Cupertino](https://github.com/mihaelamj/cupertino) installed with documentation downloaded

## Installation

```bash
# Clone the repository
git clone https://github.com/mihaelamj/cupertino-desktop.git
cd cupertino-desktop

# Build with Swift Package Manager
swift build

# Or open in Xcode
open CupertinoDesktop.xcodeproj
```

## Development Status

🚧 **In Development** - This project is in early stages

- [ ] Project structure and Package.swift
- [ ] MCPClient integration
- [ ] SwiftUI prototype
- [ ] AppKit prototype
- [ ] UI framework decision
- [ ] Core features implementation
- [ ] First release

## Related Projects

- **[cupertino](https://github.com/mihaelamj/cupertino)** - Main documentation crawler and MCP server
- **[cupertino-docs](https://github.com/mihaelamj/cupertino-docs)** - Pre-built documentation archive
- **[cupertino-sample-code](https://github.com/mihaelamj/cupertino-sample-code)** - Apple sample code repository

## Contributing

Contributions are welcome! This is an early-stage project, so major design decisions are still being made.

## License

MIT License - see [LICENSE](LICENSE) for details
