import Foundation

public extension Model {
    /// A documentation framework as listed by the backend (`list_frameworks`).
    struct Framework: Identifiable, Hashable, Sendable {
        public let id: String
        public let name: String
        public let documentCount: Int

        public init(id: String, name: String, documentCount: Int) {
            self.id = id
            self.name = name
            self.documentCount = documentCount
        }

        /// A display name with canonical Apple casing (SwiftUI, UIKit, Core Data, AVFoundation),
        /// because the backend lists frameworks by lowercase id. Looks up a curated table, then
        /// falls back to a heuristic that keeps a `Kit` suffix and capitalizes the rest.
        public var displayName: String {
            Self.canonicalNames[id.lowercased()] ?? Self.heuristicName(id)
        }

        private static let canonicalNames: [String: String] = [
            "swiftui": "SwiftUI", "swiftdata": "SwiftData", "uikit": "UIKit", "appkit": "AppKit",
            "watchkit": "WatchKit", "tvuikit": "TVUIKit", "arkit": "ARKit", "realitykit": "RealityKit",
            "cloudkit": "CloudKit", "storekit": "StoreKit", "passkit": "PassKit", "mapkit": "MapKit",
            "healthkit": "HealthKit", "homekit": "HomeKit", "gamekit": "GameKit", "spritekit": "SpriteKit",
            "scenekit": "SceneKit", "widgetkit": "WidgetKit", "pencilkit": "PencilKit", "musickit": "MusicKit",
            "photokit": "PhotoKit", "metalkit": "MetalKit", "avkit": "AVKit", "pdfkit": "PDFKit",
            "avfoundation": "AVFoundation", "avfaudio": "AVFAudio", "foundation": "Foundation",
            "coredata": "Core Data", "coreml": "Core ML", "corelocation": "Core Location",
            "coremotion": "Core Motion", "coregraphics": "Core Graphics", "coreimage": "Core Image",
            "coreaudio": "Core Audio", "coretext": "Core Text", "corebluetooth": "Core Bluetooth",
            "corefoundation": "Core Foundation", "coreservices": "Core Services", "coremedia": "Core Media",
            "coremidi": "Core MIDI", "corehaptics": "Core Haptics", "corevideo": "Core Video",
            "metal": "Metal", "metalfx": "MetalFX", "combine": "Combine", "accelerate": "Accelerate",
            "security": "Security", "kernel": "Kernel", "swift": "Swift", "matter": "Matter",
            "simd": "SIMD", "iokit": "IOKit", "iobluetooth": "IOBluetooth", "iosurface": "IOSurface",
            "webkit": "WebKit", "webkitjs": "WebKit JS", "javascriptcore": "JavaScriptCore",
            "opengles": "OpenGL ES", "audiotoolbox": "Audio Toolbox", "videotoolbox": "Video Toolbox",
            "applicationservices": "Application Services", "appstoreconnectapi": "App Store Connect API",
            "appintents": "App Intents", "vision": "Vision", "createml": "Create ML",
            "naturallanguage": "Natural Language", "mapkitjs": "MapKit JS", "objectivec": "Objective-C",
            "quartzcore": "Quartz Core", "imageio": "Image I/O", "usernotifications": "User Notifications",
            "backgroundtasks": "Background Tasks", "uniformtypeidentifiers": "Uniform Type Identifiers",
            "networkextension": "Network Extension", "devicemanagement": "Device Management",
            "applemusicapi": "Apple Music API",
        ]

        /// Best-effort casing for ids not in the curated table: a `kit` suffix becomes `Kit`,
        /// otherwise capitalize.
        private static func heuristicName(_ id: String) -> String {
            let lower = id.lowercased()
            if lower.hasSuffix("kit"), lower.count > 3 {
                return String(lower.dropLast(3)).capitalized + "Kit"
            }
            return id.capitalized
        }
    }
}
