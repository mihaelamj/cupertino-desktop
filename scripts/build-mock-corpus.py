#!/usr/bin/env python3
"""Generate the mobile mock corpus from results captured off the cupertino index.

Entries below are real results (URI, framework, title, summary) captured via the
cupertino MCP search/list tools across every source. This script expands them into
Packages/Sources/MobileBackendImpl/Resources/MockCorpus.json: the `source` is inferred
from the URI scheme, the document markdown is generated from the title and summary, and
availability defaults to a sensible baseline per source unless a row overrides it.

Re-run after capturing more searches:

    python3 scripts/build-mock-corpus.py
"""

import json
import os

# Real framework names with measured document counts (from list_frameworks).
FRAMEWORKS = [
    ("Swift", 18717), ("Foundation", 13649), ("AppKit", 13378), ("UIKit", 12416),
    ("SwiftUI", 8679), ("AVFoundation", 5348), ("RealityKit", 4456), ("Metal", 4050),
    ("ARKit", 2363), ("HealthKit", 2102), ("Network", 1949), ("Vision", 1881),
    ("StoreKit", 1414), ("MapKit", 1290), ("CloudKit", 1283), ("CoreData", 1107),
    ("Combine", 1062), ("CoreML", 913), ("CryptoKit", 665), ("Charts", 601),
    ("SwiftData", 467), ("WidgetKit", 329), ("Testing", 209), ("SceneKit", 1701),
    ("SpriteKit", 1156), ("CoreImage", 2139), ("QuartzCore", 704), ("Security", 7301),
    ("LocalAuthentication", 245), ("AuthenticationServices", 1420), ("CreateML", 1939),
    ("Observation", 19),
]

# (uri, framework, title, summary, availability). Every field is captured verbatim from
# the cupertino index. `availability` is the real per-platform minimum cupertino returned,
# or None when cupertino did not report one (no value is invented or defaulted).
DOCS = [
    # --- apple-docs: views / layout ---
    ("apple-docs://swiftui/view-groupings", "SwiftUI", "View groupings", "Present views in different kinds of purpose-driven containers, like forms or control groups.", None),
    ("apple-docs://uikit/uitraitsplitviewcontrollerlayoutenvironment", "UIKit", "UITraitSplitViewControllerLayoutEnvironment", "A trait that represents whether an ancestor split view controller is expanded or collapsed.", {"iOS": "26.0"}),
    ("apple-docs://appkit/nstextviewportlayoutcontroller", "AppKit", "NSTextViewportLayoutController", "Manages the layout process inside the viewport interacting with its delegate.", {"macOS": "12.0"}),
    ("apple-docs://appkit/view-management", "AppKit", "View Management", "Manage your user interface, including the size and position of views in a window.", {"macOS": "10.0"}),
    ("apple-docs://appkit/nsviewcontroller/viewwilllayout()", "AppKit", "viewWillLayout()", "Called just before the layout() method of the view controller's view is called.", {"macOS": "10.10"}),
    ("apple-docs://appkit/nsviewcontroller/viewdidlayout()", "AppKit", "viewDidLayout()", "Called immediately after the layout() method of the view controller's view is called.", {"macOS": "10.10"}),
    ("apple-docs://appkit/nsstackview", "AppKit", "NSStackView", "A view that arranges an array of views horizontally or vertically and updates placement when the window resizes.", {"macOS": "10.9"}),
    ("apple-docs://appkit/nscollectionviewflowlayout", "AppKit", "NSCollectionViewFlowLayout", "A layout that organizes items into a flexible and configurable arrangement.", {"macOS": "10.11"}),
    ("apple-docs://uikit/customizing-collection-view-layouts", "UIKit", "Customizing collection view layouts", "Customize a view layout by changing the size of cells in the flow or implementing a mosaic style.", {"iOS": "12.0"}),
    ("apple-docs://uikit/collection-views", "UIKit", "Collection views", "Display nested views using a configurable and highly customizable layout.", None),
    ("apple-docs://realitykit/controlling-the-layout-behavior-of-a-realityview", "RealityKit", "Controlling the layout behavior of a reality view", "Choose a strategy for sizing frames and centering 3D content.", {"iOS": "18.0", "macOS": "15.0"}),
    # --- apple-docs: animation ---
    ("apple-docs://swiftui/animation", "SwiftUI", "Animation", "The way a view changes over time to create a smooth visual transition from one state to another.", None),
    ("apple-docs://swiftui/blurreplacetransition", "SwiftUI", "BlurReplaceTransition", "A transition that animates insertion or removal by combining blurring and scaling effects.", {"iOS": "17.0", "macOS": "14.0"}),
    ("apple-docs://uikit/uiview/transition(with:duration:options:animations:completion:)", "UIKit", "UIView.transition(with:duration:...)", "Creates a transition animation for the specified container view.", {"iOS": "4.0"}),
    ("apple-docs://uikit/uiviewcontrollertransitioncoordinator", "UIKit", "UIViewControllerTransitionCoordinator", "Methods that provide support for animations associated with a view controller transition.", None),
    ("apple-docs://uikit/uiviewcontrolleranimatedtransitioning", "UIKit", "UIViewControllerAnimatedTransitioning", "Methods for implementing the animations for a custom view controller transition.", None),
    ("apple-docs://uikit/uiviewcontrollerinteractivetransitioning", "UIKit", "UIViewControllerInteractiveTransitioning", "Methods that enable an object to drive a view controller transition interactively.", None),
    ("apple-docs://scenekit/animation", "SceneKit", "Animation", "Create declarative animations that move elements of a scene, or manage imported animations.", None),
    ("apple-docs://appkit/transition-animation-keys", "AppKit", "Transition Animation Keys", "Keys that reference the transitions used as views are made visible and hidden.", {"macOS": "10.5"}),
    ("apple-docs://spritekit/sktransition", "SpriteKit", "SKTransition", "An object used to perform an animated transition to a new scene.", None),
    ("apple-docs://quartzcore/catransformlayer", "QuartzCore", "CATransformLayer", "Objects used to create true 3D layer hierarchies rather than a flattened rendering model.", {"iOS": "3.0", "macOS": "10.6"}),
    # --- apple-docs: networking ---
    ("apple-docs://foundation/urlsessionuploadtask", "Foundation", "URLSessionUploadTask", "A URL session task that uploads data to the network in a request body.", {"iOS": "7.0", "macOS": "10.9"}),
    ("apple-docs://foundation/accessing-cached-data", "Foundation", "Accessing cached data", "Control how URL requests make use of previously cached data.", None),
    ("apple-docs://foundation/nsurlerrornotconnectedtointernet", "Foundation", "NSURLErrorNotConnectedToInternet", "A network resource was requested but an internet connection has not been established.", {"iOS": "2.0", "macOS": "10.0"}),
    ("apple-docs://foundation/nsurlerrorbadserverresponse", "Foundation", "NSURLErrorBadServerResponse", "The URL Loading System received bad data from the server.", {"iOS": "2.0", "macOS": "10.0"}),
    # --- apple-docs: images / rendering ---
    ("apple-docs://coreimage/ciimage", "CoreImage", "CIImage", "A representation of an image to be processed or produced by Core Image filters.", {"iOS": "5.0", "macOS": "10.4"}),
    ("apple-docs://coreimage/cicontext", "CoreImage", "CIContext", "An evaluation context for Core Image processing with Metal, OpenGL, or OpenCL.", {"iOS": "5.0", "macOS": "10.4"}),
    ("apple-docs://coreimage/ciimageprocessoroutput", "CoreImage", "CIImageProcessorOutput", "A container for writing image data produced by a custom image processor.", {"iOS": "10.0", "macOS": "10.12"}),
    ("apple-docs://metal/streaming-large-images-with-metal-sparse-textures", "Metal", "Streaming large images with Metal sparse textures", "Limit texture memory usage by loading or unloading image detail based on MIP and tile region.", {"iOS": "17.0", "macOS": "14.0"}),
    ("apple-docs://realitykit/postprocessing-effects", "RealityKit", "Postprocessing effects", "Create special rendering effects for your RealityKit scenes.", {"iOS": "15.0", "macOS": "12.0"}),
    ("apple-docs://scenekit/scntechnique", "SceneKit", "SCNTechnique", "Augment or postprocess SceneKit rendering using additional drawing passes with custom shaders.", {"iOS": "8.0", "macOS": "10.10"}),
    ("apple-docs://spritekit/maximizing-texture-performance", "SpriteKit", "Maximizing Texture Performance", "Speed up image display and enable more images to be displayed at one time.", None),
    # --- apple-docs: data / persistence ---
    ("apple-docs://swiftdata/documentation", "SwiftData", "SwiftData", "Write your model code declaratively to add managed persistence and efficient model fetching.", {"iOS": "17.0", "macOS": "14.0"}),
    ("apple-docs://swiftdata/persistentidentifier", "SwiftData", "PersistentIdentifier", "A type that describes the aggregate identity of a SwiftData model.", {"iOS": "16.0", "macOS": "13.0"}),
    ("apple-docs://swiftdata/defaultstore", "SwiftData", "DefaultStore", "A data store that uses Core Data as its underlying storage mechanism.", {"iOS": "18.0", "macOS": "15.0"}),
    ("apple-docs://swiftui/fetchrequest", "SwiftUI", "FetchRequest", "A property wrapper that retrieves entities from a Core Data persistent store.", None),
    ("apple-docs://swiftui/sectionedfetchresults", "SwiftUI", "SectionedFetchResults", "A collection of results retrieved from a Core Data store, grouped into sections.", {"iOS": "15.0", "macOS": "12.0"}),
    ("apple-docs://coredata/nsmanagedobjectcontext", "CoreData", "NSManagedObjectContext", "An object space to manipulate and track changes to managed objects.", {"iOS": "3.0", "macOS": "10.4"}),
    ("apple-docs://coredata/nsfetchrequest/init(entityname:)", "CoreData", "NSFetchRequest(entityName:)", "Initializes a fetch request configured with a given entity name.", {"iOS": "4.0", "macOS": "10.7"}),
    ("apple-docs://coredata/syncing-a-core-data-store-with-cloudkit", "CoreData", "Syncing a Core Data Store with CloudKit", "Synchronize objects between devices and handle store changes in the user interface.", None),
    # --- apple-docs: security / auth ---
    ("apple-docs://security/keychain-items", "Security", "Keychain items", "Embed confidential information in items that you store in a keychain.", None),
    ("apple-docs://security/using-the-keychain-to-manage-user-secrets", "Security", "Using the keychain to manage user secrets", "Relieve the user of remembering small secrets by storing them in the keychain.", None),
    ("apple-docs://security/password-autofill", "Security", "Password AutoFill", "Streamline your app's login and onboarding procedures.", None),
    ("apple-docs://localauthentication/accessing-keychain-items-with-face-id-or-touch-id", "LocalAuthentication", "Accessing Keychain Items with Face ID or Touch ID", "Protect a keychain item with biometric authentication.", {"iOS": "15.5"}),
    ("apple-docs://localauthentication/larightstore", "LocalAuthentication", "LARightStore", "A container for data protected by a right.", {"iOS": "16.0", "macOS": "13.0"}),
    ("apple-docs://authenticationservices/public-private-key-authentication", "AuthenticationServices", "Public-Private Key Authentication", "Register and authenticate users with passkeys and security keys, without passwords.", None),
    ("apple-docs://authenticationservices/securing-logins-with-icloud-keychain-verification-codes", "AuthenticationServices", "Securing Logins with iCloud Keychain Verification Codes", "Use time-based codes generated on-device for a secure authentication experience.", None),
    # --- apple-docs: audio / video ---
    ("apple-docs://avfoundation/documentation", "AVFoundation", "AVFoundation", "Work with audiovisual assets, control device cameras, process audio, and configure system audio.", {"iOS": "2.2", "macOS": "10.7"}),
    ("apple-docs://avfoundation/avcapturetimecodegenerator", "AVFoundation", "AVCaptureTimecodeGenerator", "Generates and synchronizes timecode data for precise video and audio synchronization.", {"iOS": "26.0", "macOS": "26.0"}),
    ("apple-docs://avfoundation/avcapturedeferredphotoproxy", "AVFoundation", "AVCaptureDeferredPhotoProxy", "A lightly-processed photo the system may use to fetch a higher-resolution asset later.", {"iOS": "17.0"}),
    ("apple-docs://cinematic/documentation", "AVFoundation", "Cinematic", "Integrate playback and editing of assets captured in Cinematic mode into your app.", {"iOS": "17.0", "macOS": "14.0"}),
    ("apple-docs://webkit/delivering-video-content-for-safari", "Vision", "Delivering Video Content for Safari", "Improve the performance and appearance of video in your website in Safari.", None),
    # --- apple-docs: machine learning ---
    ("apple-docs://coreml/documentation", "CoreML", "Core ML", "Integrate machine learning models into your app.", {"iOS": "11.0", "macOS": "10.13"}),
    ("apple-docs://coreml/mlmodel", "CoreML", "MLModel", "An encapsulation of all the details of your machine learning model.", {"iOS": "11.0", "macOS": "10.13"}),
    ("apple-docs://coreml/mlmodelconfiguration", "CoreML", "MLModelConfiguration", "The settings for creating or updating a machine learning model.", {"iOS": "12.0", "macOS": "10.14"}),
    ("apple-docs://coreml/making-predictions-with-a-sequence-of-inputs", "CoreML", "Making Predictions with a Sequence of Inputs", "Integrate a recurrent neural network model to process sequences of inputs.", None),
    ("apple-docs://createml/creating-an-action-classifier-model", "CreateML", "Creating an Action Classifier Model", "Train a machine learning model to recognize a person's body movements.", None),
    ("apple-docs://createml/mlsoundclassifier", "CreateML", "MLSoundClassifier", "A model you train with audio files to recognize and identify sounds on a device.", {"iOS": "15.0", "macOS": "10.15"}),
    ("apple-docs://charts/rectanglemark", "Charts", "RectangleMark", "Chart content that represents data using rectangles, for heat maps and annotations.", {"iOS": "16.0", "macOS": "13.0"}),
    ("apple-docs://charts/documentation", "Charts", "Swift Charts", "Construct and customize charts on every Apple platform.", {"iOS": "16.0", "macOS": "13.0"}),
    # --- apple-docs: foundations of each anchor framework ---
    ("apple-docs://swiftui/documentation", "SwiftUI", "SwiftUI", "Declare the user interface and behavior for your app on every platform.", None),
    ("apple-docs://uikit/documentation", "UIKit", "UIKit", "Construct and manage a graphical, event-driven user interface for your iOS, iPadOS, or tvOS app.", {"iOS": "2.0"}),
    ("apple-docs://foundation/documentation", "Foundation", "Foundation", "Access essential data types, collections, and operating-system services for your app.", {"iOS": "2.0", "macOS": "10.0"}),
    ("apple-docs://combine/documentation", "Combine", "Combine", "Customize handling of asynchronous events by combining event-processing operators.", None),
    ("apple-docs://widgetkit/documentation", "WidgetKit", "WidgetKit", "Extend the reach of your app by creating widgets, watch complications, Live Activities, and controls.", {"iOS": "14.0", "macOS": "11.0"}),
    ("apple-docs://arkit/arsession", "ARKit", "ARSession", "The object that manages motion tracking, camera passthrough, and image analysis for an AR experience.", {"iOS": "11.0"}),
    ("apple-docs://observation/observable-macro", "Observation", "Observable()", "Defines and implements conformance of the Observable protocol.", {"iOS": "17.0", "macOS": "14.0"}),
    ("apple-docs://observation/observationignored", "Observation", "ObservationIgnored()", "Disables observation tracking of a property.", {"iOS": "17.0", "macOS": "14.0"}),
    # --- HIG ---
    ("hig://general/sidebars", "SwiftUI", "Sidebars", "A sidebar appears on the leading side and lets people navigate between sections in your app.", None),
    ("hig://general/split-views", "SwiftUI", "Split views", "A split view manages the presentation of multiple adjacent panes of content.", None),
    ("hig://general/layout", "SwiftUI", "Layout", "A consistent layout that adapts to various contexts makes your experience more approachable.", None),
    ("hig://general/mac-catalyst", "AppKit", "Mac Catalyst", "Create a Mac version of your iPad app to let people enjoy the experience in a new environment.", None),
    ("hig://general/motion", "SwiftUI", "Motion", "Use motion and animation to communicate, provide feedback, and add visual interest.", None),
    ("hig://general/machine-learning", "CoreML", "Machine learning", "Design app experiences that use machine learning to deliver personalized, intelligent features.", None),
    # --- Swift Evolution ---
    ("swift-evolution://SE-0306", "Swift", "SE-0306: Actors", "Introduces actors to Swift to protect mutable state from data races.", {"swift": "5.5"}),
    ("swift-evolution://SE-0343", "Swift", "SE-0343: Concurrency in Top-level Code", "Bringing concurrency to top-level code and protecting top-level variables from data races.", {"swift": "5.7"}),
    ("swift-evolution://SE-0297", "Swift", "SE-0297: Concurrency Interoperability with Objective-C", "Interoperating Swift concurrency with Objective-C completion-handler methods.", {"swift": "5.5"}),
    ("swift-evolution://SE-0338", "Swift", "SE-0338: Execution of Non-Actor-Isolated Async Functions", "Clarifies where non-actor-isolated async functions run and tightens sendability checking.", {"swift": "5.7"}),
    ("swift-evolution://SE-0376", "Swift", "SE-0376: Function Back Deployment", "Introduces @backDeployed to ship new API implementations back to older runtimes.", {"swift": "5.8"}),
    ("swift-evolution://SE-0253", "Swift", "SE-0253: Callable values of user-defined nominal types", "Lets a value with a callAsFunction method be called with function-call syntax.", {"swift": "5.2"}),
    # --- Swift Book ---
    ("swift-book://advanced-operators", "Swift", "Advanced Operators", "Define custom operators, perform bitwise operations, and use builder syntax.", None),
    ("swift-book://patterns", "Swift", "Patterns", "Match and destructure values with patterns.", None),
    ("swift-book://concurrency", "Swift", "Concurrency", "Perform asynchronous operations with async/await, tasks, and actors.", None),
    # --- Swift.org ---
    ("swift-org://index", "Swift", "Swift.org Documentation", "Language reference, API design guidelines, standard library, core libraries, and the package manager.", None),
    ("swift-org://articles_getting-started-with-cursor-swift", "Swift", "Setting up Cursor for Swift Development", "Use the Swift VS Code extension with Cursor for navigation, debugging, and testing.", None),
    # --- Apple Archive ---
    ("apple-archive://TP40004514/CoreAnimationBasics", "QuartzCore", "Core Animation Basics", "Core Animation provides a general purpose system for animating views and other visual elements.", {"macOS": "10.0"}),
    ("apple-archive://TP40006166/TransitionAnimations", "QuartzCore", "Transition Animation", "Used when it is impossible to interpolate the effect of changing a layer property.", {"macOS": "10.0"}),
    ("apple-archive://TP40006166/AnimationTimingTypesOverview", "QuartzCore", "Animation Class Roadmap", "Core Animation provides an expressive set of animation classes you can use in your app.", {"macOS": "10.0"}),
    ("apple-archive://TP40004514/ImprovingAnimationPerformance", "QuartzCore", "Improving Animation Performance", "Choose the best redraw policy and measure performance to keep frame rates high.", {"macOS": "10.0"}),
    # --- Packages ---
    ("packages://apple/swift-async-algorithms", "Combine", "AsyncAlgorithms", "An open-source package of asynchronous sequence and advanced algorithms involving concurrency.", {"swift": "5.7"}),
    ("packages://apple/swift-async-algorithms/Chunked", "Combine", "Chunked", "Group elements of an async sequence into chunks by count, time, or projection.", {"swift": "5.7"}),
    ("packages://apple/swift-collections", "Foundation", "Swift Collections", "Production-grade data structures: Deque, OrderedSet, OrderedDictionary, and more.", {"swift": "5.7"}),
    # --- Samples ---
    ("samples://swiftui-building-a-great-mac-app-with-swiftui", "SwiftUI", "Building a great Mac app with SwiftUI", "Incorporate sidebars, tables, toolbars, and other UI elements into an engaging Mac app.", {"macOS": "14.0"}),
    ("samples://swiftui-building-rich-swiftui-text-experiences", "SwiftUI", "Building rich SwiftUI text experiences", "Build an editor for formatted text using SwiftUI text editor views and attributed strings.", {"iOS": "18.0", "macOS": "15.0"}),
    ("samples://swiftui-landmarks-building-an-app-with-liquid-glass", "SwiftUI", "Landmarks: Building an app with Liquid Glass", "Enhance your app experience with system-provided and custom Liquid Glass.", {"iOS": "26.0", "macOS": "26.0"}),
    ("samples://uikit-customizing-collection-view-layouts", "UIKit", "Customizing collection view layouts", "Custom UICollectionViewLayout subclasses arranging cells as lists or grids by screen size.", {"iOS": "12.0"}),
    ("samples://coreml-classifying-images-with-vision-and-core-ml", "CoreML", "Classifying Images with Vision and Core ML", "Preprocess photos and classify their contents using a Core ML model with Vision.", {"iOS": "12.0"}),
]


def source_of(uri: str) -> str:
    return uri.split("://", 1)[0]


def build():
    documents = []
    for uri, framework, title, summary, availability in DOCS:
        source = source_of(uri)
        # The document body is the real title and abstract cupertino returned, nothing
        # synthesized. Availability is included only when cupertino reported it.
        markdown = f"# {title}\n\n{summary}"
        document = {
            "uri": uri,
            "source": source,
            "framework": framework,
            "title": title,
            "summary": summary,
            "markdown": markdown,
        }
        if availability:
            document["availability"] = availability
        documents.append(document)

    corpus = {
        "_note": "Generated by scripts/build-mock-corpus.py from results captured off the cupertino index across every source. Real framework names and counts, real Apple titles and abstracts. Life-like mock content until CupertinoDataEngine ships.",
        "frameworks": [{"id": fid, "count": count} for fid, count in FRAMEWORKS],
        "documents": documents,
    }

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "Packages", "Sources", "MobileBackendImpl", "Resources", "MockCorpus.json")
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(corpus, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    print(f"Wrote {len(documents)} documents and {len(FRAMEWORKS)} frameworks to {out}")


if __name__ == "__main__":
    build()
