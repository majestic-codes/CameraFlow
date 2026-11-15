# Changelog

The changes apps notice, by release. CameraFlow follows semantic versioning: see
[Source stability](README.md#source-stability) in the README.

## 1.0.0 - 2026-11-15

The first public release: the stock Camera app's Photo mode re-created with public API as an "Add photo" flow, with
the camera, the review and the markup, for SwiftUI and UIKit apps.

### Added

#### Presenting the flow

- `CameraFlowView`, presented in SwiftUI with `cameraFlowCover(isPresented:onDismiss:content:)` and set up with
  modifiers (see SwiftUI modifiers below), and
  `CameraFlowViewController` with `CameraFlowViewControllerDelegate` for UIKit. Both cover the screen, keep the
  interface portrait on iPhone and turn it with the device on iPad, and cannot be swiped away.
- The cover dismisses the flow together with its own sheets and alerts, waits for a presentation or a dismissal under
  way, and turns its binding false however the flow leaves.
- The controller presents itself `.fullScreen`, runs a new flow at every presentation and shows it until that flow ends,
  needs `onFinish` or a delegate, and stays until a hand-over that began on it has ended, so its delegate hears the set
  even after the app released the controller.
- A screen the app presents over the flow stops the camera and keeps the set, and a set the user accepted is handed over
  whatever happens to the view meanwhile. The cross asks before it leaves photos behind, the photos of the set and the
  ones the camera is still taking or processing.

#### Camera

- The stock Photo mode: viewfinder, shutter, flip, top bar indicators and the control panel with its sub-panels.
- Rapid shooting: the next photo is taken as soon as the camera is ready, with responsive capture and fast capture
  prioritization where the camera offers them. Photos on their way count against the photo limit and reach the app in
  the order they were shot, and the shutter shows a busy camera. A photo whose Live Photo movie or circle fails is
  handed over without it, with a notice.
- Tap to focus and expose at a point, and AE/AF Lock with a touch and hold on the viewfinder and the stock AE/AF LOCK
  badge, or AE LOCK and AF LOCK on a camera that can lock only the exposure or only the focus. VoiceOver locks and
  unlocks with an action on the viewfinder, which names what the camera can lock.
- Zoom with the lens buttons, the zoom dial and a pinch, as far as the system's recommended zoom range, the automatic
  macro of a camera with an ultra wide lens, and Lens Correction where the camera supports it.
- Flash with the Auto highlight while the scene would fire it for the next photo, at the quality that photo is taken
  with, and the state and alert of a flash that cannot fire for heat or power. A camera without a flash dims its
  controls and keeps the chosen mode, and the front camera's screen flash is offered where the camera has it.
- Live Photo, the self-timer, the aspect ratios 4:3, 16:9 and 1:1, HEIF or Apple ProRAW, and the quality of the
  photos.
- Dual Capture: the second camera in a circle of the viewfinder, composited into a copy of the photo, on devices that
  run the back and the front camera at once.
- Front-camera photos are saved unmirrored, alone and in Dual Capture, as the stock camera saves them.
- The volume buttons and the Camera Control take a photo from iOS 17.2. From iOS 18 the Camera Control offers
  Exposure, Zoom and Cameras, also while Dual Capture runs, and the lens picker follows the flow's language.
- A flip or a switch of Dual Capture waits for the photo on its way, and a shutter tap during a change of the camera
  takes its photo with the new camera.
- Pauses for another app, iPad multitasking, the background and the system's pressure, with a notice and a camera that
  comes back by itself. Under serious pressure the preview runs at 15 to 20 frames a second.
- The shutter refuses a photo when the device has less than about 100 MB free, and a photo, a save and the hand-over
  under way go on in the background for the time the system gives.
- The glyphs are public SF Symbols and drawings of the package's own, and the glass of the controls is Liquid Glass
  on iOS 26 and newer. No Apple artwork ships with the package.

#### Review and markup

- The review of the set with a pager, a strip, delete and "add more" from the photo library.
- Markup with PaperKit on iOS 26 and newer, with its first feature set: strokes, shapes, text, images and stickers.
  On iOS 17 and 18, PencilKit strokes.
- On iPad the drawing follows the system's Apple Pencil setting, and stays over the photo when the iPad turns or the
  window changes size.

#### The photo library

- Photos picked through the system picker, which needs no library access, with the movie of a Live Photo.
- Saving of the camera photos to the system photo library or to an album, at the check mark or right after each shot
  (`photoLibrarySaving.moment`), set by the app or switched by the user. A photo with a drawing becomes one asset with
  the drawing as its edit over the original.
- `CameraFlowPhoto.photoLibrarySave` reports `.saved(CameraFlowPhotoLibraryAsset)`, with the asset's
  `localIdentifier` and `isMissingDrawing`, or `.failed(CameraFlowPhotoLibrarySaveFailure)`, with the domain and the
  code of an error Photos refused the change with and a description for the app's log.
- A save that fails loses nothing: the photo stays in the set, the screen says it was not saved, and a refused library
  offers Open Settings in the Save sub-panel.

#### What the app receives

- `CameraFlowPhoto`: the original, the copy with the drawing or the second camera's circle and the result, each a
  `CameraFlowPhoto.File` with its URL and its type, the Live Photo movie, a thumbnail, the framed region and the
  outcome of the save. A public initializer builds photos for an app's own tests and previews.
- Copies with a drawing or the circle keep the metadata, the colour profile, the bit depth, the HDR gain maps, the
  depth and the mattes of the original, and hold at most 48 MP.
- The app owns the files it receives. The flow deletes every other file it made, and the next flow removes the
  directories an emptied hand-over or a crash left behind.
- Every public value is `Hashable`.

#### Configuration

- `CameraFlowConfiguration` with app constraints, user settings and session values. A user setting is a
  `CameraFlowSetting`, adjustable or fixed.
- The user's choices are reported as `CameraFlowPreferences` (`onCameraFlowPreferencesChange` in SwiftUI,
  `onPreferencesChange` or the delegate in UIKit), with a stable JSON coding, and remembered between flows in
  `UserDefaults` (`settingsMemory`), or kept by the app and passed back in `preferences`.
- The output of the photos the app receives: size, format and metadata (`output`), for the picks as well or apart
  (`libraryOutput`), and three qualities the user may pick, with the levels the app defines (`photoQualityLevels`).
- A photo limit (`photoLimit`), and a flow that ends by itself after one photo (`completion = .afterOnePhoto`).
- The flow stops the program with a message on a configuration it cannot honour and on a usage description it needs
  and the app lacks.

#### SwiftUI modifiers

- Modifiers that set properties of the configuration of a `CameraFlowView`: `cameraFlowLanguage(_:)`,
  `cameraFlowPhotoLimit(_:)`, `cameraFlowLibraryPickerEnabled(_:)`, `cameraFlowPhotoLibrarySaving(_:)`,
  `cameraFlowPhotoLocation(_:)`, `cameraFlowPhotoDirection(_:)` and `cameraFlowOutput(_:)`. The configuration the view
  is created with is the base, each modifier sets one property of it, and the modifier nearest to the view wins. The
  flow reads the result once, when it starts, and checks it with the same rules as the configuration.
- `onCameraFlowFinish(perform:)`, `onCameraFlowCancel(perform:)` and `onCameraFlowPreferencesChange(perform:)`, the
  actions of the flow. As with SwiftUI's own actions, the flow calls the ones of the latest update of its view.
- `CameraFlowView()` and `CameraFlowView(configuration:locationProvider:)`, which take their actions from these
  modifiers. A flow that starts without `onCameraFlowFinish` or `onCameraFlowCancel` stops the program.
- `cameraFlowCover` carries the modifiers of the flow from the view that presents it into the flow, as
  `fullScreenCover` carries the environment, and the modifiers inside its content win over them.

#### Location and direction

- The photos record where they were taken, as the stock Camera's do (`photoLocation`): the GPS of the file, the
  location of the saved asset and the location of the Live Photo movie. The flow asks for access itself, or the app
  does, or the photos record none.
- An approximate location is recorded with its accuracy when Precise Location is off.
- An app with a location of its own passes a `locationProvider`, whose location counts as the flow's own does, while it
  is valid and at most 60 seconds old, or 20 minutes for an approximate one.
- A photo picked from the library keeps the location of its file, where the system picker hands one over, whatever
  `photoLocation` says: only an output that strips the metadata takes it out.
- The direction of the camera from the compass, true or magnetic north (`photoDirection`).

#### Introduction

- A step before each system request the user has not answered: the camera, the location and the photo library. Its
  one button, Continue, always brings the system's request (`onboarding`).

#### Localization

- 37 languages, Latin American Spanish (`es-419`) among them, with the stock camera's own texts in each.
- `language`: the flow's texts, numbers, plural forms and capitals in a language the app names, whatever the device's
  language, with English and the numbers of the language for one the package lacks. VoiceOver speaks that language
  while the flow is on screen.
- In a right-to-left language the review and the Markup controls mirror, and the camera controls keep the stock order.

#### Accessibility

- VoiceOver labels and values, adjustable exposure, lenses and mode switch, announcements, focus that follows the
  control panel, Magic Tap to take a photo and the escape gesture.
- A hardware keyboard: Escape, Return, and Command-Z and Shift-Command-Z in Markup.
- Dynamic Type for the flow's own texts, and the Large Content Viewer and touch areas of 44 points for the fixed-size
  chrome of the camera.
- Reduce Motion, under which the camera's controls fade or take their places at once instead of moving, the lift of the
  controls under a sub-panel and the top bar included.
- Bold Text, Increase Contrast, Button Shapes and Voice Control, and Differentiate Without Color, under which the Dual
  Capture, Save and Auto flash indicators show their state by their shape too.

#### Privacy

- A privacy manifest: no tracking and no collected data, with the reasons for `UserDefaults` and the free disk space.
- The log shows file paths, picked file names and photo metadata values as private data only, and the package's own
  error texts hold no path.

#### Requirements

- iOS 17 or newer, on iPhone and iPad. Xcode 26.2 or newer, with Swift 6.2.3: the Swift tools version of the package,
  which its three `@nonexhaustive` enums need, so an older Xcode refuses the package with a version message. No
  dependencies. The package builds in an app with a Mac Catalyst destination.
- A 1.x release adds API and never changes or removes any. It adds no case to a public enum, except to the three marked
  `@nonexhaustive`: `CameraFlowPhoto.Source`, `CameraFlowPhotoLibrarySaveFailure` and `CameraFlowPhotoLibraryError`.

#### Example and testing support

- The `CameraFlowExample` app, which opens the flow through SwiftUI and UIKit, with launch arguments for a fixed state
  and UI tests.
- `@_spi(Testing)` fixtures: a simulated camera, simulated access and photos taken by themselves.

#### Documentation

- A DocC catalog of the public API, which the Swift Package Index builds.
