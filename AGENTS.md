# Lint

Swift must pass `swiftlint lint --strict` from the repository root, with SwiftLint 0.63.2, the version CI runs. Read `.swiftlint.yml` first and match it. Changes to lint rules need the owner's approval.

# Project knowledge base

CameraFlow is a Swift package for iOS: the whole "Add photo" flow with a shooting mode and a review mode, built on a SwiftUI copy of the stock Photo camera. One library target, `CameraFlow`, at the repository root. `Example/` holds the demo app, `CameraFlowExample`, and its UI tests, `CameraFlowExampleUITests`.

The package runs on iOS 17 and newer, on iPhone and iPad, and builds with Xcode 26.2 or newer and Swift 6.2.3, the Swift tools version of `Package.swift`, which its three `@nonexhaustive` enums need, so an older Xcode refuses the package with a version message. `Package.swift` also declares macOS 14, for the unit tests only. The unit tests need Xcode 27: its `swift test` builds with Swift Build, which compiles `Localizable.xcstrings`.

`Sources/CameraFlow` is one module in layers, one folder each. A folder depends only on the folders above it in this list, and a file belongs to the deepest folder that holds it, so `State/Flow` comes after `State`:

- `API/Values`: the public value types (`CameraFlowConfiguration`, `CameraFlowPhoto`, `CameraFlowInitialState`, the settings enums). Depends on nothing.
- `Domain`: the protocols the logic reaches the device through, and the values they speak in. Depends on nothing but `API/Values`.
  - The camera: `CameraService` and its events (`CameraSessionEvent`: among them `captureReadinessChanged` with `CaptureReadiness`, and the flash scene and `FlashAvailability`), `CameraPreview`, `CameraPictureCover` and `CameraHaptics`. `CameraService.lockFocusAndExposure(atDevicePoint:)` and `unlockFocusAndExposure()` are the AE/AF Lock, and `monitorFlashScene(for:format:)` has the camera watch its scene for the flash as the next photo in that format would be taken. `PhotoCaptureCapabilities` is what a running camera can do, among it what AE/AF Lock holds there (`lockableAdjustments`, a `LockableAdjustments`: the focus and the exposure, or one of the two, and nil for a camera that can lock neither). `CaptureAdmission` is the set's room for the next photo, counting the photos in flight (`captureRefusal(photosInFlight:)`).
  - The other services: `DeviceAttitudeSensor`, `LocationAuthorizer`, `PhotoLocationSource`, `PhotoHeadingSource`, `PhotoLibraryPick`, `PhotoLibraryWriter`, `MarkupCanvas`, `MarkupRenderer`, `PreferenceStore`, `StorageSpace` (the free room the shutter checks) and `BackgroundWork` (the background time of a photo, a save and the hand-over).
  - `ForegroundFollowing`: the rule the location, the compass and the motion sensors follow the app's foreground by. The adapters pass UIKit's notification names, so `Domain` stays free of UIKit. `UnitGeometry.swift`: rectangles in unit coordinates, in which the viewfinder and the photo speak of the circle and of the framed part.
- `DesignTokens`: measured sizes, motion, typography, colours and glyphs. Depends on nothing but `API/Values`. `CameraTextStyle` holds the numbers of every chrome text style, which the views and the text-fit tests share. No artwork ships: a glyph is a public SF Symbol by its name (public from iOS 17), which the running iOS draws, or an outline of the package's own (`CameraGlyphOutline`, `FlowGlyph`). `Resources` holds no image catalog, and `CameraGlyphTests` checks it.
- `Capture/Processing`: a delivered photo turned into files (crop, location, thumbnail, file store, delivery). Every photo file is read through `ImageSourcePhoto` and written through `ImageEncoding` (with `ImageMetadataTag`, `PhotoPixelDescription` and `CGImagePropertyOrientation+Pixels`): a new reader or writer uses them.
- `Capture/Device`: the device camera. The only folder that imports `AVFoundation`, and `CaptureRotation.swift` the only file that imports it `@preconcurrency`. Its rules that need no device (`CaptureParts`, `DualCapturePhoto`, `CaptureFrameRateThrottle`, `CapturesInFlight`, `CaptureFocusLockWait`) sit outside `#if os(iOS)`, so they are tested on macOS. A queue-confined `@unchecked Sendable` type asserts its queue with `dispatchPrecondition` where other files reach its state: a member of `CaptureSessionCore` that its extensions or other files call on the queue starts with the assertion, and every other member reaches the queue itself.
  - `CapturePhotoOutputSetup` turns on responsive capture and fast capture prioritization. `CapturePhotoSettingsBuilder.qualityPrioritization(for:output:)` is the one rule of the quality a photo is taken at, the output's `maxPhotoQualityPrioritization` for a processed photo and `.balanced` for RAW, and the flash scene is monitored at that same quality, so the Auto highlight answers for the next photo. One readiness coordinator per photo output (`CapturePhotoReadiness`) tells `CaptureReadinessTracker` which outputs take a photo now: the pair is ready only when both are.
  - `CaptureDeviceInspector.lockableAdjustments(of:)` is the one rule of what AE/AF Lock holds on a device, which the photo capabilities report, and `CaptureDeviceControl.lockFocusAndExposure(of:)` locks only that. `CaptureFocusLockWait` holds the lock until the camera has settled into it. `CaptureFlashWatch` follows the flash scene in the mode and the format it was given, on every output it moves to, and whether the flash can fire.
- `Capture/Simulated`: the camera with no hardware, for the simulator and the tests.
- `Haptics`: the Taptic Engine behind `CameraHaptics`.
- `Motion`: the device attitude from CoreMotion behind `DeviceAttitudeSensor`. The only folder that imports `CoreMotion`. Each flow has its own `CMMotionManager`, beside any the app runs: the package takes none from the app.
- `Location`: the location access, the location of the photos and the direction of the camera from Core Location behind `LocationAuthorizer`, `PhotoLocationSource` and `PhotoHeadingSource`, the location the app's `locationProvider` returns, and their simulated stand-in. The only folder that names `CLLocationManager`. Its rules that need no device (`LocationAccessRequests`, `CompassUpdates`, the access of Core Location in `CoreLocationAccess.swift`) are tested on macOS.
- `Library`: a photo library pick behind `PhotoLibraryPick`. `PhotosUI` is imported here and in the one view that shows the picker sheet.
- `PhotoLibrary`: saving to the system photo library behind `PhotoLibraryWriter`, the rendered content of an edit it saves, and its simulated stand-in. The only folder that imports `Photos`. The error of a change Photos refused (`CameraFlowPhotoLibraryError(refusedChange:)`) is made outside the iOS-only writer, so its tests run on macOS.
- `Markup`: drawing on a photo, PaperKit on iOS 26 and newer and PencilKit below, behind `MarkupCanvas` and `MarkupRenderer` of `Domain`: the canvases, the renderer, and `EmbeddedMarkupCanvas`, the canvas the screen runs the flow with. It names nothing of `State`: the flow's models over that canvas are named in `Views/Flow/EmbeddedFlowModels.swift`. The only folder that imports `PencilKit` and `PaperKit`. A class there never stores a PaperKit value type directly: the runtime cannot lay it out on a system without PaperKit.
  - The two canvases share their editing (`MarkupEdit` over `EngineDrawing`), their tool picker and undo (`MarkupCanvasTools` over `EngineCanvas`) and their view (`MarkupCanvasView`, which keeps the canvas at its opening size and scales it into later frames). The parts that need no canvas are tested on macOS.
  - PencilKit stops a test process without a bundle identifier when a stroke is made or moved, so the tests decode fixture drawings and scale PaperKit drawings only.
- `State`: the models of the camera screen, one concern each, and `PhotoCameraModel`, which owns them and is the only model that knows the others. Uses `Domain` and `Capture/Processing`, never a concrete camera.
  - `CameraSessionModel`: the running camera. Access, the start of one camera or of the pair, what it can do, which cameras run, its failure and its interruption, its previews, and the picture covers while it changes. It holds the camera's life (`CameraLife`), and `CameraChangeGate` keeps a change of the camera and a capture apart.
  - `CameraNoticeModel`: what the camera said last, the failed capture, what a photo was taken without and the change of the dual camera. `OrientationModel`: how the phone is held, how the interface stands, and the turn of the upright elements. `CaptureControlsModel`: the Camera Control's overlay.
  - `ZoomModel`, `PhotoSettingsModel`, `ControlPanelModel`, `FocusModel`, `ShutterModel`, `DualCameraModel` and `OnboardingModel`: the zoom, the settings of the next photo with the user's choices, the control panel, the focus, the shutter, the second camera's circle and the introduction.
  - `PhotoSettingsModel` holds the flash of the running camera (`CameraFlash`) next to what the camera can do, with the flash rules in `PhotoSettingsModel+Flash.swift`, where `followingCaptureFormat(_:)` has the camera monitor the flash scene again when a change of the settings moves the format of the next photo. `FocusModel` holds the focus at a tapped point, its reticle and the AE/AF Lock of a long press (`FocusLock`), which locks what the running camera can (`lockableAdjustments`) and shows the stock badge that names it: AE/AF LOCK, or AE LOCK and AF LOCK on a camera that can lock only the exposure or only the focus. A camera that can lock neither takes no long press and no VoiceOver lock.
  - `ShutterModel` takes a tap once the camera is ready, while earlier photos are still in flight (`photosInFlight`, the taps, a countdown included), processes and hands the photos over one at a time in shutter order (`ShotTurn`), and shows the camera's readiness (`ShutterBusyIndication`). `firedPhotosInFlight` counts only the photos the camera was asked to take, from the moment the shot fires until the photo is handed over or fails.
  - `PhotoQualityModel` and `PhotoLibrarySavingModel`: the two settings the set shares, and the only models of `State` that a model other than `PhotoCameraModel` holds: the settings hold both, the introduction asks for the library through the saving, and the saving keeps the library's refusal.
  - `PhotoCameraModel` hands each model the values it needs from another, such as what a camera that has started offers, hears what each reports (`PhotoSettingsModel.onUserChange`, `ZoomModel.onLensChange`), and runs every action that touches more than one: the life of the camera, the circle, the shutter (`capture()`, which gives `ShutterModel` a `PhotoShot`, and `onCaptureEnded`, which `CameraFlowModel` hears at the end of every press) and the notices (`notice`, `clearNotices()`). A new concern gets its own model or value, owned there. No other model holds or calls one of the camera's models, besides the two shared settings.
- `State/Flow`: the flow above the camera. `CameraFlowModel` owns `PhotoCameraModel`, the set (`PhotoSetModel`), the review (`PhotoReviewModel` with `ReviewImageModel`) and the markup session (`PhotoMarkupModel`), runs what crosses between them and picks the notice line (`FlowNotice`). It reaches the camera through the API of `PhotoCameraModel` only, never through the camera's models. The review and the markup read the set they show.
  - The photos in flight count: `PhotoSetModel.hasRoom(besides:)` and `CameraFlowModel.canShoot` leave room for them. A running self-timer keeps the shutter, so that a tap can stop it.
  - The exit rule: the cross, its Escape key and the VoiceOver escape gesture leave at once only while `leavesPhotosBehind` is false, with no photo in the set and none the camera took on its way. Otherwise the exit alert asks first, and `ExitConfirmation` counts both. The alert closes by itself when the last photo on its way fails on an empty set (`captureEnded()`), and a flow that ends after one photo waits for its answer before it hands the photo over (`finishAfterOnePhoto()`): Stay hands it over, Leave deletes it.
  - The hand-over: `PhotoSetHandOverObserver` hears a hand-over begin and end, answers whether a set reaches anyone (`receivesSets`) and hears of a set deleted because it reached nobody (`setDeleted()`). `PhotoSetModel+HandOver.swift` writes the copies and deletes a set nobody receives, and `AcceptedSave` keeps the drawing a check mark saved.
- `Presentation`: layout, touch interpretation and text, without SwiftUI, so it is tested on macOS. It also holds the plan of a presentation (`FlowPresentationPlan`), the orientations of the flow's interface (`FlowInterfaceOrientations`), the moves of VoiceOver (`FlowFocusTarget`), the kind of device a text names (`DeviceFamily`) and `FlowSelfDismissal`, the dismissal `CameraFlowViewController` asks of itself once its flow has ended, which a controller presented again never inherits. In `Presentation/Text`, the accessibility texts of the camera chrome live in `CameraSettingSpeech` and `CameraControlText`, the visible ones in `CameraSettingText`, and the texts of the AE/AF Lock and of a flash that cannot fire in `FocusLockText` and `FlashUnavailableText`. The AE/AF Lock badge has its place in `CameraScreenLayout+FocusLock.swift`, its view in `Views/Screen/FocusLockBadgeView.swift` and its tokens in the `+FocusLock` files of `DesignTokens`.
- `Views`: SwiftUI. A view takes the models it reads, not `PhotoCameraModel`. Only `Views/Flow/CameraFlowScreen.swift` takes that, and hands a view an action that touches several models as a closure, such as `capture` or `toggleDualCamera`. `Views/Flow` holds the views of the flow, the review and the markup. `Views/Components` holds the chrome's shared helpers (`TouchDownButtonStyle`, `showsLargeContent(_:)`, `keyboardShortcut(_:isActive:)`, `exposureAdjustableAction(_:)`). `Views/Panel/PanelLiftMotion` has the lens row, the dial and the shutter take the places a sub-panel gives them at once under Reduce Motion. `Views/Screen/CameraCaptureButtons.swift` is the only file that imports `AVKit`, for the hardware capture buttons.
- `Composition`: picks the camera, builds the model, runs the screen and plays the launch fixtures.
  - `UsageDescription` checks the app's usage descriptions when the flow starts, `canCarryLocation` decides whether the photos can carry a location at all, and `ExpiringActivityWork` asks for the background time.
  - `FlowPresentationLifetime` gives each presentation one flow, and `FlowOutcomeRelay` observes the hand-overs of the controller's flows (given by `FlowPresentationLifetime.begin(_:)`) and keeps the controller while they run. Both are tested on macOS.
  - `FlowSetup` is what a `CameraFlowView` starts its flow with: its configuration with the properties the SwiftUI modifiers set (`FlowConfigurationChanges`, the nearest modifier last), read and checked once, when the flow starts, and closures that reach `FlowReceivers`. `FlowReceivers` holds the closures of the latest view with the modifiers' over them (`FlowCallbacks`), which the view hands over at every update, and belongs to the owner of the flow: the view's own state, or the presentation (`FlowPresentationLifetime.receivers`). These are tested on macOS, and the SwiftUI glue in a hosted view on the simulator (`CameraFlowModifierHostingTests`).
  - `UserDefaultsPreferenceStore` holds the defaults the preferences are kept in: no system type gets a package protocol that would bring a public conformance the SDK lacks, such as `Sendable`.
- `API/Screens`: the public views, and `PortraitHostingController`, the host of a presented flow.

No SwiftUI, UIKit or `AVFoundation` in `API/Values`, `Domain`, `Capture/Processing`, `Capture/Simulated`, `State` and `Presentation`. A concrete type of an adapter folder (`Capture/Device`, `Capture/Simulated`, `Haptics`, `Motion`, `Location`, `Library`, `PhotoLibrary`, `Markup`) is named in its own folder and in `Composition` only, and `EmbeddedMarkupCanvas` in `Views` and `API/Screens` too. `Tests/CameraFlowTests/ArchitectureTests.swift` checks these rules on the source text: the folder order (no file names a type declared only in a folder after its own), the homes of the frameworks, the public declarations, the concrete types, and that no model of `State` but `PhotoCameraModel` names another one besides the two shared settings.

- `Tests/CameraFlowTests` holds the Swift Testing suites, in folders named after the layer they test. They run against a fake camera: no test needs a real one, and none skips itself when there is none.
- `Tests/CameraFlowTests/TestSupport` holds the fakes and the conveniences only tests need. The suites that check the source text read the checkout through `SourceTree.checkout()`, once per run. A test that sends a camera event awaits `RecordingCameraService.simulate(_:)`, and the work the handler starts is awaited with `settle`, never assumed to have run or not.
- The text-fit suites measure the texts of every language in the shipped text styles (`CameraTextStyle`), down to the 320 pt window of Slide Over, with a few percent left for the platform's rendering.
- `Example/CameraFlowExampleUITests` holds the UI tests of the demo app, the only XCTest code: they run the flow over the simulated camera through the launch arguments of `Example/Sources/CameraFlowLaunchOptions.swift`, which stop the launch on an unknown, repeated or conflicting argument. Every launch pins the language (`-AppleLanguages`, `-AppleLocale`), and starts from a fresh state (`-cameraFlowResetState`) unless it follows up on what an earlier launch stored.

The commands, from the repository root:

- `swift build` and `swift test` build the package and run the unit tests on macOS, where the code inside `#if os(iOS)` (the screens, the views, the device camera) is not compiled.
- `xcodebuild build-for-testing -scheme CameraFlow -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO` compiles all of the package and its tests for iOS, with no simulator and no signing, as CI does.
- On a simulator the package tests run one at a time, since parallel HEIC encodes hang there: `xcodebuild test -scheme CameraFlow -destination 'platform=iOS Simulator,name=<an iPhone of xcrun simctl list devices available>' -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO`. A test that needs what the simulator's ImageIO does not do (an ISO gain map, a 10-bit HEIC encoded again, every metadata key of a JPEG copy, a RAW decoder) takes `.needsDeviceImageIO(_:)` of `Tests/CameraFlowTests/TestSupport/SimulatorImageIO.swift`, which skips it there with the gap as the reason. The UI tests run the same way, one at a time, from `-project Example/CameraFlowExample.xcodeproj -scheme CameraFlowExample`. The Development section of `README.md` gives contributors these commands, with the English simulator `CameraFlowLibraryUITests` needs: a change to one is made in both.
- Before a release the maintainer runs the checks no CI job runs, as "Before a release" in `CONTRIBUTING.md` lists them: the build with Xcode 26.2, the oldest Xcode the README names, the package tests on the newest iOS and on an iOS 18.6 simulator, where the iOS 17 to 25 path runs, PencilKit without PaperKit, the Example's UI tests with `CameraFlowMarkupUITests` on that runtime too, and `otool -L` of a Release build of the Example, whose PaperKit line must end with `weak)`.
- `xcodebuild docbuild -scheme CameraFlow -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO OTHER_DOCC_FLAGS=--warnings-as-errors` builds the documentation and fails on a link to a symbol that does not exist.

`public` appears under `API` only:

- `API/Screens`: `CameraFlowView`, `CameraFlowViewController` with `CameraFlowViewControllerDelegate`, `cameraFlowCover`, and the SwiftUI modifiers of `CameraFlowModifiers.swift` (the `cameraFlow…` properties of the configuration and the `onCameraFlow…` actions), `nonisolated` as SwiftUI's own, which reach `CameraFlowView` through the environment. The documentation shows SwiftUI through `CameraFlowView()` or `CameraFlowView(configuration:)` and these modifiers in every sample; the initializer that takes closures keeps a short reference of its own and no samples. The cover carries them from the presenting view into its content (`PresentedFlow.inheritedModifiers`), and the controller's flow gets none.
- `API/Values`, what the app configures: `CameraFlowConfiguration`, `CameraFlowPhotoLimit`, `CameraFlowInitialState`, `CameraFlowSetting`, the camera settings (`CameraFlowFlashMode`, `CameraFlowAspectRatio`, `CameraFlowTimer`, `CameraFlowPhotoFormat`), `CameraFlowOutput` with `CameraFlowOutputSize`, `CameraFlowOutputFormat` and `CameraFlowOutputMetadata`, `CameraFlowLibraryOutput`, `CameraFlowQuality` with `CameraFlowQualityLevels` and `CameraFlowQualityLevel`, `CameraFlowPhotoLibrarySaving` with its `Destination` and `Moment`, `CameraFlowPreferences`, `CameraFlowSettingsMemory`, `CameraFlowOnboarding`, `CameraFlowPhotoLocation`, `CameraFlowPhotoDirection`, `CameraFlowLanguage` and `CameraFlowCompletion`.
- `API/Values`, what the flow hands back: `CameraFlowPhoto` with its `Source` and `File`, `CameraFlowPhotoLibrarySave`, `CameraFlowPhotoLibraryAsset`, `CameraFlowPhotoLibrarySaveFailure` and `CameraFlowPhotoLibraryError`.
- `@_spi(Testing)`, for launch fixtures: `CameraSetting`, `CameraPanelPresentation`, `CameraOrientation`, `SimulatedScene`, `SimulatedAccess` with `CameraFlowConfiguration.simulatedAccess`, the fixture properties of `CameraFlowInitialState` and `CameraFlowQuality.distinct(within:levels:)`.

Every public value is `Hashable`. `CameraFlowPhoto`, `CameraFlowPhoto.File` and `CameraFlowPhotoLibraryAsset` have public initializers, for an app's own tests and previews.

Source stability: a 1.x release adds API and never changes or removes any. It adds no case to a public enum, except to the three marked `@nonexhaustive` (`CameraFlowPhoto.Source`, `CameraFlowPhotoLibrarySaveFailure`, `CameraFlowPhotoLibraryError`), whose documentation says that a `switch` over them needs `@unknown default`. Every other public enum says in its documentation that its cases are fixed for 1.x: a new value comes as a new type or property, never as a new case. The stored coding of `CameraFlowPreferences` stays readable by every 1.x release. The `@_spi(Testing)` fixtures are outside this promise. A change of the public API is entered in `CHANGELOG.md`.

The documentation catalog is `Sources/CameraFlow/CameraFlow.docc`: the landing page `CameraFlow.md`, with the source stability rule and the topic groups of the public API, and a page for each type whose members it groups. A new public symbol gets a doc comment and its place in a topic group. A doc comment names a public symbol as a link (``CameraFlowConfiguration/photoLocation``), so that the documentation build finds a stale name, and an internal or `@_spi` one in code voice. `.spi.yml` builds the documentation on the Swift Package Index. The source tree the architecture tests read is the `.swift` files, so the catalog is in no layer.

Every parameter of `CameraFlowConfiguration` belongs to one of four groups (app constraints, user settings, session only, internal), listed in the table of its documentation: a new parameter is entered there. A user setting (group 2) is a `CameraFlowSetting` and has its optional value in `CameraFlowPreferences` (`flashMode`, `isLivePhotoEnabled`, `aspectRatio`, `timer`, `photoFormat`, `isDualCameraEnabled`, `isPhotoLibrarySavingEnabled`, `photoQuality`), which is what the flow remembers (`CameraFlowSettingsMemory`) and reports. Each preference is its setting's `Value?` under the setting's own name, so `photoLibrarySaving.isEnabled` is `isPhotoLibrarySavingEnabled`, and that name is its key in the stored JSON: renaming one loses what users stored. `CameraFlowQualityLevels`, `CameraFlowLibraryOutput`, `CameraFlowOnboarding`, `CameraFlowPhotoLocation`, `CameraFlowPhotoDirection`, `CameraFlowLanguage` and `CameraFlowCompletion` are app constraints (group 1).

Texts live in `Resources/Localizable.xcstrings` (English source and 36 translations, 37 languages in all, listed in `StringCatalog.languages` of `Tests/CameraFlowTests/TestSupport/StringCatalog.swift`): every user-facing string is translated into all catalog languages. A new string gets Latin American Spanish (`es-419`) too, with Apple's es-419 terms (Configuración, Tomar foto, Agregar, Listo, Marcado). A text is looked up with `bundle: localization.bundle, locale: localization.locale` of the `FlowLocalization` the text type is made with, which views read from the environment (`flowLocalization`), so `CameraFlowConfiguration.language` reaches every text. A text's locale is `FlowLocalization.locale`: the language of the texts, with the region and the digits of the formats (`textLocale(of:formats:)`), so the plural forms and the capitals follow the texts. The privacy manifest is in `Resources/PrivacyInfo.xcprivacy`: a new use of a required-reason API is declared there. The app's usage descriptions of the system resources the flow asks for are checked when the flow starts (`UsageDescription`): a new resource enters its key there.

# Code Style

Not caught by SwiftLint — obey anyway.

## `try?`: one exception, cleanup in `deinit`

`try?` stays banned everywhere except best-effort cleanup in a `deinit`, which cannot throw: removing what the
object leaves behind, where a failure has nowhere to go. The site carries a comment naming this exception.

## `Bool?`: the preferences only

An optional Boolean is banned (`discouraged_optional_boolean`) except for the switches of `CameraFlowPreferences`
(`isLivePhotoEnabled`, `isDualCameraEnabled`, `isPhotoLibrarySavingEnabled`), which are nil while the user never
chose. They sit in the one `swiftlint:disable discouraged_optional_boolean` region of the package, with a comment
that says so.

## No abbreviations

Identifier = full word. Always. SwiftLint catches <3 chars only.
`ctx`→`context`, `propName`→`propertyName`, `fm`→`fileManager`, `rect`→`rectangle`, `r/g/b/a`→`red/green/blue/alpha`.
Exception: a locked public API that cannot be renamed.

## Name by type

Name after type/concept. No generic placeholder.
`AVCaptureSession` → `session` (not `item`), `AVCaptureDevice` → `device` (not `data`).

## Long line → variable, not bracket-wrap

Long line from nested call → extract named variable. Not multi-line brackets to save lines.
`CameraFlowPhoto.File(url: copyURL, contentType: try PhotoFilePreview(url: copyURL).contentType)` too long → `let preview = try PhotoFilePreview(url: copyURL)` then `CameraFlowPhoto.File(url: copyURL, contentType: preview.contentType)`.
No nested `try`: not `try String(contentsOf: try #require(url))` — unwrap on its own line first.

## Shorthand optional binding

`if let fontSize` — not `if let f = fontSize`, not `if let fontSize = fontSize`.

## Pattern matching: `case let` outside, switch as expression

Bind once, in front: `case let .changeRefused(errorDomain, errorCode)` — not `case .changeRefused(let errorDomain, let errorCode)`.
Same in `guard case let` and `if case let`.

When a switch is the whole body, write it as an expression — no `return` per arm:
```swift
var heightPerWidth: CGFloat {
    switch self {
    case .fourByThree: 4.0 / 3.0
    case .sixteenByNine: 16.0 / 9.0
    case .square: 1
    }
}
```

## Blank line before func after `{`

`{` directly followed by `func` → blank line between.

## Fail loud, validate once

Unknown input (a launch argument of the Example, an orientation name in the app's Info.plist, a configuration no
flow can honour) throws or stops the program — never a skip or a silent default.
Validate at the boundary once; past it no `?`, `?? []` or "cannot happen" branches — carry the
proven value, not the key to look it up again.

One sanctioned exception, the stored-preference exception: a stored preference (`CameraFlowPreferences`) whose value
is not one of its property's reads as nil and the other properties are kept, since the stored bytes are outside the
flow's control. It is written as `do`/`catch`, the site carries a comment naming this exception, and the dropped key
reaches the caller, which logs it (`PreferencesMemory`).

## Logging

The package logs under the one subsystem `CameraFlow` (`Logger.camera(_:)`). An error is logged with
`Logger.error(_:cause:)` and a reason with `Logger.info(_:reason:)`: `LoggedReason` shows the package's own errors of
a photo file and of a drawing (`CameraServiceError`, `PhotoOutputFailure`, `MarkupFailure`) whole and any other error
by its localized description. File paths, picked file names and photo metadata values show only as private data, and a
package error text never holds a path: a file it names goes without its folders. Every value in a log message states
its privacy, which `LoggingTests` checks.

## Test-only API lives in TestSupport

A method with no caller in package sources does not live in package sources. Conveniences needed only by
tests belong under `Tests/CameraFlowTests/TestSupport`.

## Tests: no force, fail loud

Test suite is Swift Testing (`import Testing`, `@Test func ...`, `#expect`, `#require`). XCTest stays in the UI tests of the Example only.

No force-unwrap, no silent `?? default`.
- `x!` → `try #require(x)`
- `x as!` → `try #require(x as? T)`
- `try!` → `try` (test `throws`)
- A helper that promises values requires them: `FlowHarness.makeStartedFlow` throws and requires its photo count, so
  its caller writes `try`.
- An array the code under test returns is indexed only after `try #require(array.count == n)`.

A test that reads the source tree or runs a tool (`Foundation.Process`) is compiled for macOS only (`#if os(macOS)`), as `ArchitectureTests` is: an iOS test host has neither.

## Swift Testing rules

`#expect(!x)` defeats macro expansion — use `#expect(x == false)`.
`#expect(throws: (any Error).self)` accepts anything — use the specific type (e.g. `CameraServiceError.self`).
Floating-point: `expectClose(a, b, tolerance: t)` of `TestSupport/NumberExpectations.swift`, not `#expect(abs(a - b) < t)`: a failure names both numbers. Inside a larger condition: `isClose(a, to: b, tolerance: t)`. Frames: `expectClose(frame, expected)` of `TestSupport/FrameExpectations.swift`. Never `#expect` a method of a number, such as `#expect(a.isClose(to: b, tolerance: t))`: with an argument such as `1.82 * 18.5 / 22`, the macro's expansion drops the method's result and the check passes whatever the number. The package has no dependencies, its tests included.
Loop with N independent `#expect` rows → `@Test(arguments: [...])` so each row failure is isolated. Skip parametrize when iterations accumulate into one assertion.
Tags, once a test needs one, live in `Tests/CameraFlowTests/TestSupport/Tags.swift`.

## No NS*

Foundation's NS-prefixed types are forbidden where Swift has its own: `Regex` not `NSRegularExpression`, `Date` not
`NSDate`, `URLRequest` not `NSURLRequest`, `String` not `NSString`. An NS type an Apple API requires is allowed:
- `NSObject` as the base of an Objective-C delegate (`AVCapturePhotoCaptureDelegate`, `CLLocationManagerDelegate`) or
  of a selector target (`ForegroundFollowing`, `MarkupUndoObservation`).
- `NSCoder` in the unavailable `init?(coder:)` of a UIKit subclass.
- `NSKeyValueObservation` and `NSKeyValueObservingOptions` for key-value observation, `NSObjectProtocol` for the
  token of a notification observer.
- `NSOrderedSet` for `PHAssetCollectionChangeRequest.addAssets(_:)`, `NSCopying` and `NSObjectProtocol` for the
  value of an `AVMutableMetadataItem`.
- `NSError`, to read the domain and the code of any error (`CameraFlowPhotoLibraryError(refusedChange:)`), with a
  comment at the site.
- `NSFont`, `NSImage` and `NSAppearance` in the macOS branches the unit tests run: the font of a text style, the
  look-up of a system symbol and the drawing of PencilKit strokes.
- `NSPredicate` in the UI tests, which `XCTNSPredicateExpectation` and `XCUIElementQuery.matching(_:)` take.

## Comments

Don't comment by default — write code that reads without one (names, small functions, one idea
per line). Comment only where the code alone cannot explain itself: a non-obvious rule the code
implements, a value's meaning, a sanctioned exception (`try?` in a `deinit`, `swiftlint:disable`).

A comment says what the code does or means. Never: why an alternative was rejected, the history
of the change (an audit, a review, an earlier version), which phase or caller will use it, or that
a branch is "unreachable". One or two sentences, no semicolons — start a new sentence instead. If
the code needs an essay, simplify the code.

These rules are for `//` comments. A `///` documentation comment is as long as its reader needs: the public API
documents what an app meets (the defaults, the preconditions, what the flow does with the user's files), and
SwiftLint's `missing_docs` asks for it on every public declaration.
