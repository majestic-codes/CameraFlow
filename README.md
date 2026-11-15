# CameraFlow

<p align="center"><img src="https://github.com/user-attachments/assets/15c93b02-6563-4fd8-9a96-957a66a9e19f" alt="CameraFlow: zoom dial and lenses, Dual Capture, review" width="800"></p>

A Swift package with the whole "Add photo" flow for an iOS app: the user takes photos with a camera that looks and
behaves like the stock Photo mode, picks more from the photo library, reviews the set, draws on a photo, and hands
the set back to the app as files. It is built on public API only, for SwiftUI and UIKit apps.

- The stock Photo mode re-created in SwiftUI over `AVFoundation`: viewfinder, shutter, flip, top bar indicators and the
  control panel with its sub-panels.
- Rapid shooting: the shutter takes the next photo while the ones before it are still processed.
- Tap to focus and expose at a point, and AE/AF Lock: touch and hold the viewfinder to hold the focus and the
  exposure, with the stock AE/AF LOCK badge.
- Zoom with the lens buttons, the zoom dial and a pinch, and Lens Correction where the camera has it.
- Flash with the stock Auto highlight and the state of a flash that cannot fire, Live Photo, timer, aspect ratio (4:3,
  16:9, 1:1), format (HEIF or Apple ProRAW) and photo quality.
- Dual Capture: the second camera in a circle of the viewfinder, composited into a copy of the photo.
- The volume buttons and the Camera Control take a photo, and the Camera Control offers Exposure, Zoom and Cameras.
- Review of the set with a pager, a strip, delete and "add more".
- Photos from the library through the system picker, which needs no library access.
- Markup: drawing on a photo, with PaperKit on iOS 26 and newer and PencilKit strokes on iOS 17 and 18.
- Optional saving of the camera photos to the system photo library or to an album, when the set is accepted or right
  after each shot.
- Where each photo was taken, as the stock Camera records it, and optionally the direction of the camera.
- An introduction before the system asks for the camera, the location and, where the flow saves, the photo library.
- 37 languages, VoiceOver, Dynamic Type for the flow's own texts, Reduce Motion and the other accessibility settings.
- iPhone and iPad.

## Screenshots

<table>
<tr>
<td align="center"><img src="https://github.com/user-attachments/assets/a95e0fe7-65f7-453a-82da-cf2e30631f7b" alt="Control panel" width="200"><br>Control panel</td>
<td align="center"><img src="https://github.com/user-attachments/assets/77cce4c9-d348-41e3-9b9f-f4e09d51a3aa" alt="Format and quality" width="200"><br>Format and quality</td>
<td align="center"><img src="https://github.com/user-attachments/assets/a1d9b7c1-b2eb-4f41-8ba4-cba2d5e55a23" alt="Timer" width="200"><br>Timer</td>
<td align="center"><img src="https://github.com/user-attachments/assets/d3a30532-a8c9-4181-ac74-e9c731b4d553" alt="Exposure" width="200"><br>Exposure</td>
</tr>
<tr>
<td align="center"><img src="https://github.com/user-attachments/assets/6d60287d-48f6-483d-a58f-ff9995e93208" alt="Markup" width="200"><br>Markup</td>
<td align="center"><img src="https://github.com/user-attachments/assets/bf1e649f-1283-4d09-a94c-7c6f153c5d6d" alt="Review" width="200"><br>Review</td>
<td align="center"><img src="https://github.com/user-attachments/assets/9b785989-3470-414c-b53e-3807ab0d32f1" alt="Dual Capture" width="200"><br>Dual Capture</td>
<td align="center"><img src="https://github.com/user-attachments/assets/dc0413b9-d9b4-4d56-9acd-b6f05a003143" alt="Introduction" width="200"><br>Introduction</td>
</tr>
</table>

## Requirements

| | |
|---|---|
| iOS | 17.0 or newer, on iPhone and iPad |
| Xcode | 26.2 or newer |
| Swift | 6.2.3 or newer: the Swift tools version of the package, which its three `@nonexhaustive` enums (SE-0487) need, so an older Xcode refuses the package with a version message |

The package compiles against the iOS 26 SDK, for PaperKit and Liquid Glass, and runs from iOS 17 on. What differs by
the iOS a device runs:

| iOS | Glass of the controls | Markup | Buttons that take a photo |
|---|---|---|---|
| 26 and newer | The system's Liquid Glass | PaperKit | The volume buttons, and the Camera Control with Exposure, Zoom and Cameras |
| 18 | A blurred, tinted imitation | PencilKit strokes | The volume buttons, and the Camera Control with Exposure, Zoom and Cameras |
| 17.2 to 17.x | A blurred, tinted imitation | PencilKit strokes | The volume buttons |
| 17.0 and 17.1 | A blurred, tinted imitation | PencilKit strokes | None |

The package supports iOS only. It builds in an app with a Mac Catalyst destination, but the flow is not tested on a
Mac, neither as a Mac Catalyst app nor as an iPhone or iPad app on a Mac with Apple silicon, and not on Apple Vision
Pro. The package also declares macOS 14, for its unit tests only: the screens exist on iOS alone.

## Installation

Swift Package Manager, by URL:

```swift
dependencies: [
    .package(url: "https://github.com/majestic-codes/CameraFlow", from: "1.0.0")
],
targets: [
    .target(name: "App", dependencies: [.product(name: "CameraFlow", package: "CameraFlow")])
]
```

In Xcode: File > Add Package Dependencies, the same URL with the rule Up to Next Major Version from 1.0.0, and the
product `CameraFlow`.

## Info.plist keys

| Key | When |
|---|---|
| `NSCameraUsageDescription` | Always: the flow asks for the camera. |
| `NSPhotoLibraryAddUsageDescription` | The flow may save to the photo library: `photoLibrarySaving.isEnabled` is on or adjustable, with the destination `.library`. Saving into the library asks for add-only access. |
| `NSPhotoLibraryUsageDescription` | The flow may save to an album (`.album(named:)`): finding or creating an album needs read-write access. |
| `NSLocationWhenInUseUsageDescription` | `photoLocation` is `.automatic`, the default: the flow asks for when-in-use access, and the system shows this text in its alert. An app that asks itself (`.appRequestsAccess`) needs it for its own request. |

The flow checks these keys when it opens and stops the program with a message that names a key it needs and the app
lacks: without it the system would end the app at the request for the camera or the photo library, possibly after a
whole set was taken, and ignore a request for the location. A flow whose photos should record no location sets
`configuration.photoLocation = .off` and needs no location key, and so does a flow whose photos cannot carry a location
(see Location).

The flow never uses the microphone: the movie of a Live Photo has no sound. Picking from the library goes through the
system picker and needs no key. An app with several languages localizes these texts in an `InfoPlist.xcstrings` String
Catalog of its app target. The Example has its own in `Example/Sources/InfoPlist.xcstrings`, in every language of the
package.

## Quick start

### SwiftUI

```swift
import CameraFlow
import SwiftUI

struct AddPhotoButton: View {
    @State private var isFlowPresented = false
    @State private var photos: [CameraFlowPhoto] = []

    var body: some View {
        Button("Add photo") {
            isFlowPresented = true
        }
        .cameraFlowCover(isPresented: $isFlowPresented) {
            CameraFlowView()
                .onCameraFlowFinish { finished in
                    isFlowPresented = false
                    photos.append(contentsOf: finished)
                }
                .onCameraFlowCancel { isFlowPresented = false }
        }
    }
}
```

`cameraFlowCover` works like `fullScreenCover` and keeps the interface portrait on iPhone while the flow is on screen
(see iPad below for the iPad). Setting the binding to false dismisses the flow together with any sheet or alert the
flow shows, and the binding turns false however the flow leaves. A change of the binding while a presentation, a
dismissal or another sheet is under way waits for it to end, and a sheet that stays on screen gets the flow over it.
The content is hosted by its own controller, so it does not inherit the environment of the presenting view, except the
flow's SwiftUI modifiers (see SwiftUI modifiers below): pass anything else it needs explicitly.

`CameraFlowView()` opens the default flow, and `CameraFlowView(configuration:)` the flow of a configuration (see
Configuration). Modifiers give the flow its actions, and set some properties of its configuration (see SwiftUI
modifiers). Every action is called on the main actor. `onCameraFlowFinish` gets the photos of the set once, when the
user accepts it with the check mark, and `onCameraFlowCancel` reports the user's own exit with the cross. The flow
cannot be swiped away: the cross is the user's way out, and it asks before it leaves photos behind, the photos of the
set and the ones the camera is still taking or processing (see Leaving the flow below).

A `CameraFlowView` reads its configuration and its location provider once, when its flow starts: a view created again
with other values keeps running the flow it has, with the configuration it started with. The one exception is
`configuration.language`: the texts on the screen follow the language of the latest view, while the Camera Control's
lens picker keeps the one the flow started with. The flow calls the actions of the latest update of the view, as
SwiftUI calls its own.

### UIKit

```swift
import CameraFlow
import UIKit

final class AlbumViewController: UIViewController {
    private var photos: [CameraFlowPhoto] = []

    func addPhoto() {
        let controller = CameraFlowViewController(
            onFinish: { [weak self] finished in
                self?.photos.append(contentsOf: finished)
            },
            onCancel: {}
        )
        present(controller, animated: true)
    }
}
```

The controller covers the whole screen (`modalPresentationStyle` is `.fullScreen`, so the presenter gets its usual
appearance calls), stays portrait on iPhone, cannot be swiped away and dismisses itself once the flow finished or was
cancelled, after the results were delivered. Set `dismissesAutomatically` to false to dismiss it yourself. Every
presentation runs a new flow with an empty set, so one controller may be presented again, and it then shows its new flow
until that flow ends, also when the flow before ended while the controller was leaving the screen. An app that shows
another screen after the flow sets `dismissesAutomatically` to false, calls `dismiss(animated:completion:)` in
`onFinish` and presents that screen from the completion. A sheet presented over the flow shares its dark window.

An app that listens through a delegate sets it in place of the closures:

```swift
import CameraFlow
import UIKit

final class GalleryViewController: UIViewController, CameraFlowViewControllerDelegate {
    private var photos: [CameraFlowPhoto] = []

    func addPhoto() {
        let controller = CameraFlowViewController()
        controller.delegate = self
        present(controller, animated: true)
    }

    func cameraFlowViewController(_ controller: CameraFlowViewController, didFinishWith photos: [CameraFlowPhoto]) {
        self.photos.append(contentsOf: photos)
    }

    func cameraFlowViewControllerDidCancel(_ controller: CameraFlowViewController) {}
}
```

The closures and the delegate both receive every result, so an app uses one of them. A controller on screen needs
`onFinish` or a delegate, and stops the program without either: the photos of an accepted set would be lost. The
delegate is weak. The hand-over of an accepted set outlives the screen, and the controller stays until a hand-over that
began on it has ended, so its delegate hears the set even when the app dismissed and released the controller
meanwhile. A delegate that no longer exists hears nothing, and a set that reaches neither `onFinish` nor a delegate is
deleted: an app whose sets must arrive whatever becomes of its delegate passes `onFinish`.

### Leaving the flow

The cross, its Escape key and the VoiceOver escape gesture leave the flow at once while the set is empty and no photo is
on its way. Otherwise the exit alert asks first. It counts the photos of the set and the ones the camera is still taking
or processing, and says whether photos taken with the camera would be gone for good, which a photo saved to the photo
library right after its shot is not. A photo that fails is no longer counted, and when the last photo on its way fails
while the set is empty, the alert closes and the flow stays. Leave deletes the set, the photos on their way included,
and closes the camera with its self-timer, the location, the compass and the motion sensors. A self-timer that still
counts down has no photo yet: on an empty set the cross leaves at once and stops it.

### iPad

The flow shows the iPhone interface on iPad, laid out for the larger screen: the camera stands in a column in the
middle, as wide as the top bar, the viewfinder and the controls under it fit the height of the window, with the
controls at their iPhone sizes. A window up to 440 points wide, a phone or a narrow iPad window, gets the whole width.
A window down to 320 points wide works: a text that does not fit wraps or is set smaller. A window shorter than the
stock arrangement narrows the column and shrinks the grid of tiles so nothing leaves it, and in a tall narrow window
the viewfinder sits in the middle of the height that is free.

iPad ignores the portrait lock of a presented controller unless the app requires full screen, so on iPad the
interface turns with the device. The flow follows it: in a landscape interface the viewfinder is landscape (4:3, 16:9
or 1:1 as chosen) and shows the camera level with the horizon, the photos are taken the way the device is held, and
the camera's elements turn only by what lies between the device and the interface, so they stand upright while the
interface turns with the device and turn as on iPhone while the rotation is locked. An app that allows no portrait
orientation gets the flow in the orientations it allows.

A host app that runs on iPad (`TARGETED_DEVICE_FAMILY` includes 2) declares every iPad orientation, as iPadOS expects
of an app that supports multitasking:

```
INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
```

or `UISupportedInterfaceOrientations~ipad` with the same four values in its Info.plist. Without them Xcode warns that
all interface orientations must be supported unless the app requires full screen.

The layout follows Split View, Slide Over and Stage Manager windows, but iPadOS pauses the camera while other apps
share the screen, as it pauses the stock Camera: the flow says "Camera unavailable with other apps open" and the
camera comes back once the app has the screen to itself. The library, the review and the markup go on working
meanwhile. An app with the `com.apple.developer.avfoundation.multitasking-camera-access` entitlement keeps the camera
running there, since AVFoundation turns multitasking access on by default for such an app.

## What the app receives

The flow hands the set over once, when the user accepts it, with the photos in their order: to `onCameraFlowFinish` in
SwiftUI, to `onFinish` or the delegate in UIKit. Each is a `CameraFlowPhoto`:

| Property | Meaning |
|---|---|
| `id` | Identifies the photo within the app's lifetime. |
| `source` | `.camera` or `.photoLibrary`. A minor release may add a source, so a `switch` over it needs `@unknown default`. |
| `original` | The original as the flow's output has it, a `CameraFlowPhoto.File`: its `url` and its `contentType`, such as a HEIC, a JPEG or a DNG. |
| `livePhotoMovieURL` | The movie half of a Live Photo, a QuickTime movie, nil for a still photo. |
| `markedUp` | The copy with the drawing, the second camera's circle or both, nil for a photo with neither. |
| `result` | What the user finished: `markedUp` when there is one, `original` otherwise. |
| `thumbnail` | A small upright `CGImage` of the result. |
| `framedRegion` | The part of the upright photo the viewfinder showed, in unit coordinates with the origin at the top left, when the file holds more than that: a 16:9 or 1:1 RAW photo, which is handed over whole in the sensor's 4:3, and a 16:9 or 1:1 HEIF or JPEG photo that holds data the crop cannot keep, such as depth. Nil when the file is what the viewfinder framed. |
| `photoLibrarySave` | What became of the photo in the system photo library, nil when the flow did not save it (see Saving to the photo library). |

The copy (`markedUp`) is upright, with the original's metadata, brought to the output as the original is. Its type is
the original's, except where ImageIO cannot write that: a copy of a RAW photo (DNG) or of a picked GIF, WebP or HEIF is
a HEIC under an output of the `.original` format, so read `result.contentType` rather than assume the original's. The
copy keeps the colour profile of the photo and its bit depth, as far as its type holds it: a 10-bit HEIC stays 10-bit,
and a JPEG is 8-bit. With the metadata kept it also keeps the auxiliary images, turned upright with the photo: the HDR
gain maps, brought to no boost under the drawing and the circle, the mattes and the depth. It holds at most 48 MP (8064
x 6048 pixels), so a larger picture from the library is scaled down to that. Clear parts of a picture stay clear in a
PNG, HEIC or TIFF copy and become white in a JPEG copy. The copy of a spatial photo is its left eye.

A Live Photo picked from the library comes with its movie as the library has it, unless the output strips the
metadata: the movie holds the place and the camera of the shot, so such a pick comes as its still.

### File ownership and cleanup

- The files of `original`, `livePhotoMovieURL` and `markedUp` belong to the app from the moment the set is handed
  over, and they are all the flow leaves: every file it made on the way (the camera's full file kept for the photo
  library beside a scaled output, a copy a drawing replaced, a full-size copy rendered for the library) is deleted
  before the hand-over. Each is a finished file, written to its end. They sit in a temporary directory, which the system
  may purge: move the files you keep, usually `result`, and delete the rest.
- A copy saved to the system photo library is the library's, never one of these files: `photoLibrarySave` tells
  whether it exists.
- The flow deletes every file it does not hand over: a photo the user deleted from the set, and every photo of a set
  the user left with the cross.
- A set the user accepted outlasts the view: the hand-over runs to its end and the app receives the set once, with files
  that exist.
- When the presentation ends without a finish or a cancel, because the app took the cover away or dismissed the
  controller, the camera closes, the photos of the set are deleted and the app hears of neither. A screen the app
  presents over the flow, such as a lock screen, stops the camera and keeps the set, and the camera comes back when
  that screen leaves.
- A directory the app emptied is removed by the next flow, and so is one a crash or a kill of the app left behind.

```swift
import CameraFlow
import Foundation

func keep(_ photos: [CameraFlowPhoto], in directory: URL) throws -> [URL] {
    try photos.map { photo in
        let destination = directory.appendingPathComponent(photo.result.url.lastPathComponent)
        try FileManager.default.moveItem(at: photo.result.url, to: destination)
        let leftovers = [photo.original.url, photo.livePhotoMovieURL, photo.markedUp?.url]
        for case let leftover? in leftovers where leftover != photo.result.url {
            try FileManager.default.removeItem(at: leftover)
        }
        return destination
    }
}
```

### Photos in an app's tests and previews

Every public value is `Hashable`, so photos go into sets, serve as picker tags and drive `.onChange(of: photos)`.
`CameraFlowPhoto` has a public initializer for an app's own tests and previews, which takes the values as they are:
the flow makes the photos of a set itself, and the files are the app's to provide.

```swift
import CameraFlow
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

func makePreviewPhoto(file: URL, thumbnail: CGImage) -> CameraFlowPhoto {
    CameraFlowPhoto(
        source: .camera,
        original: CameraFlowPhoto.File(url: file, contentType: .heic),
        thumbnail: thumbnail,
        photoLibrarySave: .saved(CameraFlowPhotoLibraryAsset(localIdentifier: "preview"))
    )
}
```

## Configuration

Everything is a property of `CameraFlowConfiguration`. The default configuration is a complete flow.

```swift
import CameraFlow
import Foundation

func makeConfiguration() -> CameraFlowConfiguration {
    var configuration = CameraFlowConfiguration()
    configuration.photoLimit = .maximum(5)
    // Offers the Live Photo switch, off at first. The default has no Live Photo at all.
    configuration.camera.isLivePhotoEnabled = CameraFlowSetting(false)
    configuration.camera.photoFormat = .fixed(.heif)
    configuration.camera.isDualCameraEnabled = .fixed(false)
    configuration.output.size = .standard
    configuration.output.format = .jpeg(quality: 0.8)
    configuration.photoQuality = CameraFlowSetting(.high)
    configuration.photoQualityLevels.medium = CameraFlowQualityLevel(size: .longSide(maximum: 1440))
    configuration.photoLibrarySaving.destination = .album(named: "Field photos")
    configuration.photoLibrarySaving.isEnabled = CameraFlowSetting(true)
    configuration.settingsMemory = .userDefaults(suiteName: "group.example.shared")
    configuration.onboarding = .off
    configuration.photoLocation = .appRequestsAccess
    configuration.photoDirection = .recorded
    configuration.language = .specific(Locale.Language(identifier: "uk"))
    configuration.completion = .userConfirms
    return configuration
}
```

### Every property and its default

| Property | Default | Group |
|---|---|---|
| `isLibraryPickerEnabled` | `true`: the round library button and the "+" tile of the review | 1 |
| `photoLimit` | `.unlimited`; `.maximum(n)` or `.single` limit the set, camera and library together | 1 |
| `completion` | `.userConfirms`: the user accepts the set with the check mark | 1 |
| `camera.flashMode` | Auto, adjustable | 2 |
| `camera.isLivePhotoEnabled` | Off and fixed: the flow has no Live Photo control and no Live Photo | 2 |
| `camera.aspectRatio` | 4:3, adjustable | 2 |
| `camera.timer` | Off, adjustable | 2 |
| `camera.exposureBias` | 0, adjustable | 3 |
| `camera.photoFormat` | HEIF, adjustable: RAW is offered where the camera and the output allow it | 2 |
| `camera.isDualCameraEnabled` | Off, adjustable where the device runs two cameras at once | 2 |
| `camera.zoomFactor` | `nil`: the main camera at 1x | 3 |
| `output` | The files as they are: `size`, `format` and `metadata` keep the original | 1 |
| `libraryOutput` | `.sameAsCamera`: the picks get the output above | 1 |
| `photoQuality` | High and fixed: no quality row on the Format panel | 2 |
| `photoQualityLevels` | Medium at most 1920 pixels in the output's format, low at most 1920 pixels as a HEIC at 0.5 | 1 |
| `photoLibrarySaving.isEnabled` | Off and fixed: nothing is saved and there is no Save control | 2 |
| `photoLibrarySaving.destination` | `.library` | 1 |
| `photoLibrarySaving.moment` | `.whenSetAccepted` | 1 |
| `preferences` | Empty: no stored choices of the app's | - |
| `settingsMemory` | `.userDefaults()`: the standard `UserDefaults`, keys under the prefix `CameraFlow.` | 1 |
| `onboarding` | `.automatic`: a step before each system request the user has not answered | 1 |
| `photoLocation` | `.automatic`: the photos record where they were taken, and the flow asks for access | 1 |
| `photoDirection` | `.off` | 1 |
| `language` | `.system`: the language the system resolves for the app | 1 |

### The groups of parameters

| Group | Set by | The user changes it | Remembered | Reported |
|---|---|---|---|---|
| 1. App constraints | The app | Never | No | No |
| 2. User settings | The app: the first value, and whether it is fixed | In the camera | Yes | Yes |
| 3. Session only | The app: the first value | In the camera | No | No |
| 4. Internal | Launch fixtures and tests | Never | No | No |

`isUserAdjustable` of every `CameraFlowSetting` is of group 1. Besides `camera.exposureBias` and `camera.zoomFactor`,
group 3 holds what the user does on the screen: the focus, the open panel and which camera is in the circle. Group 4
is the `@_spi(Testing)` properties of `CameraFlowInitialState` and `simulatedAccess` (see Testing support).

`preferences` is no setting of its own: it carries the user's stored choices of group 2 back into the flow, one
optional value for each (`CameraFlowPreferences`).

### A user setting, from the first value to the next flow

Every setting of group 2 is a `CameraFlowSetting`: a value, and whether the user may change it. `CameraFlowSetting(x)`
is adjustable and has its control on the camera screen. `.fixed(x)` has no control and holds for the whole flow.

- The flow reports every change the user makes as a `CameraFlowPreferences`, to `onCameraFlowPreferencesChange` in
  SwiftUI and to `onPreferencesChange` or the delegate in UIKit, and never a change the flow makes on its own.
- By default the flow remembers the user's choices itself (`settingsMemory`, in `UserDefaults` under the key
  `CameraFlow.preferences.v1`), so an app does nothing. Like the stock camera's Preserve Settings, it remembers the
  group 2 settings and never the exposure, the zoom or the focus.
- An app that keeps the choices itself sets `settingsMemory = .off`, stores what is reported and passes it back in
  `preferences`.

Each preference is the value of its setting under the setting's own name: `camera.flashMode` is `flashMode`,
`camera.isLivePhotoEnabled` is `isLivePhotoEnabled`, `photoLibrarySaving.isEnabled` is `isPhotoLibrarySavingEnabled`,
and nil while the user never chose. `CameraFlowPreferences` is `Codable` with a stable coding: each property under its
own name, the enumerations as their raw values and the switches as JSON Booleans. A value stored by an older version
decodes with nil for what it lacks, an unknown key is ignored, and a stored value that is not one of a property's
values reads as nil while the others are kept.

The value a setting opens with is the first of these that exists:

1. the app's value, when the app fixed the setting (`CameraFlowSetting.fixed`);
2. the value the app passed in `preferences`;
3. the value the flow remembers;
4. the app's value (`CameraFlowSetting.value`).

A value the camera cannot honour (Live Photo on a camera without it or outside 4:3, the second camera on a device that
cannot run it, a quality the output leaves no room for, RAW where it is not offered) is taken as the nearest one it
can while the photo is taken. What is remembered and what is reported stay as the user chose them.

```swift
import CameraFlow
import Foundation
import SwiftUI

struct StoredPreferencesFlow: View {
    let onDone: ([CameraFlowPhoto]) -> Void
    @AppStorage("cameraFlowPreferences") private var stored = Data()

    var body: some View {
        CameraFlowView(configuration: configuration)
            .onCameraFlowPreferencesChange { preferences in
                do {
                    stored = try JSONEncoder().encode(preferences)
                } catch {
                    assertionFailure("Cannot encode the preferences: \(error)")
                }
            }
            .onCameraFlowFinish(perform: onDone)
            .onCameraFlowCancel { onDone([]) }
    }

    private var configuration: CameraFlowConfiguration {
        var configuration = CameraFlowConfiguration()
        configuration.settingsMemory = .off
        if !stored.isEmpty {
            do {
                configuration.preferences = try JSONDecoder().decode(CameraFlowPreferences.self, from: stored)
            } catch {
                assertionFailure("Cannot decode the stored preferences: \(error)")
            }
        }
        return configuration
    }
}
```

### Ending after one photo

`configuration.completion = .afterOnePhoto` (default `.userConfirms`) ends the flow by itself after one photo taken with
the camera or picked from the library: the set holds one photo whatever `photoLimit` says, the picker lets the user pick
one, and the flow hands the photo over as soon as it is in. A second quick tap of the shutter takes no photo: the flow
ends with the first. A photo that arrives while the exit alert asks waits for the answer: Stay hands it over, Leave
deletes it. The user never sees the review or the markup, so the photo comes without a drawing, and with the second
camera's circle where it was on. A save to the photo library still running is waited for. A shot that fails, a pick that
cannot be loaded or a picker closed without a pick leave the flow open, and so does a save that fails at the hand-over,
with its notice: the check mark then hands the photo over.

### Output

`configuration.output` is what the app takes at most for the photos taken with the camera and their copies, and by
default for the photos picked from the library as well. `configuration.libraryOutput` decides the picks:

| `libraryOutput` | Picks from the library | The user's quality |
|---|---|---|
| `.sameAsCamera` (default) | The output above | Narrows them too |
| `.separate(CameraFlowOutput())` | As the library gave them | Leaves them alone |
| `.separate(output)` | That output | Leaves them alone |

So an app constrains the camera photos only with an output plus `.separate(CameraFlowOutput())`, and the picks only
with the default output plus `.separate(output)`. The copy of a camera photo in the system photo library is never
constrained: it is the camera's own photo.

| Property | Values | Default |
|---|---|---|
| `size` | `.original`, `.longSide(maximum:)`, `.standard` (1920 pixels on the long side) | `.original` |
| `format` | `.original`, `.jpeg(quality:)`, `.heic(quality:)` | `.original` |
| `metadata` | `.kept`, `.stripped` | `.kept` |

The default output adds no step of its own: it does not scale, re-encode or strip a file. A photo from the library is
the library's file byte for byte. A camera photo is the camera's file byte for byte when it is 4:3 and records neither a
location nor a direction, and always as RAW, which records neither. A location or a direction is written into the
metadata of the camera's file without encoding the image again. A 16:9 or 1:1 HEIF or JPEG photo is cropped from the
sensor's 4:3 and encoded once more, at a compression quality of 0.9, with its metadata and its auxiliary images. A photo
that holds data the crop cannot keep, such as depth, is handed over whole with `framedRegion`, as a 16:9 or 1:1 RAW
photo is.

The size of a photo is two steps. The camera captures at its own resolution, which the output never changes: 12 MP where
the camera has it (4032 x 3024 for 4:3), its largest otherwise. The 24 MP and 48 MP of a Pro camera are not captured,
and neither is a deferred photo (`AVCaptureDeferredPhotoProxy`), which is not a finished full-size photo when it is
delivered. `size` then scales a larger photo down with ImageIO, after the capture. So `.original` is the camera's 12 MP,
not the most the sensor has, and a `.longSide` above 4032 gives 12 MP.

The compression is a setting of its own, the quality inside `format`: ImageIO writes it as
`kCGImageDestinationLossyCompressionQuality`. A photo that is encoded again, because it is scaled, its format changes or
its metadata is stripped, is a new lossy generation, and so is the crop of a 16:9 or 1:1 HEIF or JPEG photo:

- With the metadata kept, a re-encoded photo keeps everything else its file holds: the HDR gain maps scaled with the
  pixels, the mattes and the depth, every metadata tag, the XMP included, and in a HEIC the bit depth of a 10-bit photo
  and both images of a spatial photo. A JPEG is 8-bit and holds one image, so a spatial photo becomes its left eye. The
  file embeds a thumbnail of its own pixels, and its EXIF size and subject area describe them.
- A scaled photo of the `.original` format is encoded again as well, at a compression quality of 0.9: in its own type
  where ImageIO writes that type (JPEG, HEIC, PNG and TIFF), and as a HEIC otherwise, such as a DNG, a HEIF, a GIF or a
  WebP picked from the library. A DNG from the library is read as its RAW image and encoded from it.
- `.stripped` drops EXIF, GPS (with the direction), maker notes, XMP and IPTC: the file holds the pixels, upright, their
  colour profile and their size, encoded again as 8-bit SDR without gain maps, mattes or depth.
- A copy with a drawing or the circle is written once, straight in the output, by the same rules: with `.kept` it has
  the auxiliary images of the original, with `.stripped` none.

RAW is offered only where the camera has it and the output takes a DNG as it is: in the `.original` format, with the
metadata kept and at a size no smaller than the camera's photo (`.original`, or a long side of at least 4032 at 12 MP).
A DNG cannot be scaled, re-encoded or stripped.

### Photo quality

`CameraFlowQuality` has three values, `high`, `medium` and `low`. A quality narrows the output and never widens it.

- `high` is the output as the app set it.
- `medium` is by default at most 1920 pixels on the long side, in the format of the output.
- `low` is by default at most 1920 pixels on the long side, as a HEIC at a compression quality of 0.5, or in the
  output's own format at 0.5 or at the output's quality where that is lower.

By default the quality is `high` and fixed, so the flow shows no choice. Make it adjustable to give the user the
quality row on the Format panel, with the approximate size of one photo under it and an indicator in the top bar while
it is not `high`, and say what the levels mean:

```swift
import CameraFlow

func makeQualityConfiguration() -> CameraFlowConfiguration {
    var configuration = CameraFlowConfiguration()
    configuration.photoQuality = CameraFlowSetting(.high)
    let compact = CameraFlowOutputSize.longSide(maximum: 1280)
    configuration.photoQualityLevels.medium = CameraFlowQualityLevel(size: .original, format: .jpeg(quality: 0.7))
    configuration.photoQualityLevels.low = CameraFlowQualityLevel(size: compact, format: .jpeg(quality: 0.6))
    return configuration
}
```

A level's size is the smaller of its own and the output's: `.original` keeps the size of the output, so the medium
level above is a smaller file at the photo's size. A level's format with a compression quality is taken as it is where
the output keeps the original format; where the output names a format, the photo stays in it at the lower of the two
qualities. The panel offers a quality only when its output differs from the output of every quality above it: with
the default levels under an output of 1920 pixels the row has High and Low. RAW can be chosen with `high` only, and
stays on the panel dimmed under another quality. The quality applies to the photos taken after it is chosen, to the
picks while they share the camera's output, and to the copies of such photos, never to the copy in the photo library.

### Saving to the photo library

Off by default. `configuration.photoLibrarySaving.isEnabled` switches it on, or lets the user switch it with the Save
indicator in the top bar and the Save tile, and `destination` is `.library` (add-only access, enough under limited
access) or `.album(named:)` (read-write access, which limited access does not give). A camera photo is saved once, as
the camera's own file: full size, with all its metadata and location, and its Live Photo movie paired with it. A photo
with the second camera's circle is saved as the full-size copy with the circle, the way the viewfinder showed it. A
photo picked from the library is never saved. `moment` says when:

| `moment` | When | Deleted from the set, or the flow left with the cross | A drawing |
|---|---|---|---|
| `.whenSetAccepted` (default) | At the check mark, the photos still in the set | Never saved | One asset that shows the drawing as its edit over the original, which the user can revert to in Photos |
| `.afterEachPhoto` | Right after each shot taken while saving is on | The saved copy stays in the library | Reaches the app only: the library keeps the photo as it was taken |

Under `.afterEachPhoto` the user goes on shooting while a save runs, the hand-over waits for the saves still running,
and the files of a photo deleted meanwhile are removed once its save has read them. Switching saving on saves the
shots from then on, switching it off keeps what was saved, and the exit alert counts a saved photo as kept. A Live
Photo with a drawing is saved as a still with the drawing as its edit, since its movie cannot show the drawing, so
Revert in Photos brings back the still photo.

Access is asked for in the introduction of a flow that opens with saving on, when the user switches saving on, or else
at the first photo saved. The photos are saved one after the other. A refused library (denied, restricted, or limited
access for an album) leaves a notice and switches off a saving the user may switch, without remembering it off, and
the Save sub-panel offers Open Settings while the user can grant the access there. A flow that opens with saving on
over a library refused before says so at once. A save that fails loses nothing: the photo stays in the set and is
handed over all the same, and the screen says that it was not saved. Under `.whenSetAccepted` a failed save keeps the
set open once with the notice, and the next check mark saves the photos the library did not take and hands the set
over whatever becomes of them. A photo is reported as saved only once Photos created its asset, in the album too where
the destination is one: the asset and its place in the album are one change. The files of an asset get neutral
names, a UUID with the extension of their type.

`CameraFlowPhoto.photoLibrarySave` is `.saved(CameraFlowPhotoLibraryAsset)` or
`.failed(CameraFlowPhotoLibrarySaveFailure)`, and nothing else. The asset has the `localIdentifier` of its `PHAsset` and
`isMissingDrawing`, true when the photo comes to the app with a drawing the asset does not show: it was saved right
after its shot, at a check mark before the drawing changed, or Photos could not take the drawing as the edit. The
failure is a refused access or a `CameraFlowPhotoLibraryError`: too little room (`notEnoughSpace`), an album that takes
no photo (`albumNotWritable`), a drawing that could not be rendered as the edit (`drawingNotWritten`), a change without
an asset (`noAssetCreated`), or `.changeRefused(errorDomain:errorCode:)` with the error Photos refused the change with:
in `PHPhotosErrorDomain`, `PHPhotosError.Code(rawValue: errorCode)` reads the code. Both failure enums describe
themselves in English for the app's log, and a minor release may add cases to them, so a `switch` needs
`@unknown default`:

```swift
import CameraFlow

/// What the app tells the user about a photo the photo library did not take, nil for every other photo.
func libraryNote(for photo: CameraFlowPhoto) -> String? {
    guard case let .failed(failure) = photo.photoLibrarySave else { return nil }
    switch failure {
    case .accessDenied, .accessRestricted:
        return "Turn on Photos access in Settings to save your photos there."
    case .limitedAccess:
        return "Saving into the album needs full Photos access."
    case .libraryError:
        return "Photos could not save the photo."
    @unknown default:
        return "The photo was not saved to Photos."
    }
}
```

### Onboarding

`configuration.onboarding` is `.automatic` by default: before the system asks for an access the flow needs, the flow
shows a step that says what the access is for, with one button, Continue, which always brings the system's request. A
user who does not want to give the access refuses it in the system's alert, as Apple's guidelines for screens before a
request ask. A step is shown only while the user has not answered that access, in this order:

| Step | Shown when | A refusal in the system's alert |
|---|---|---|
| Camera | The camera has not been asked for | The viewfinder says the access is denied, with a button to the app's page of Settings; the cross and the library still work |
| Location | `photoLocation` is `.automatic`, the camera is granted (now or before) and when-in-use location has not been asked for | The flow goes on and its photos record no location |
| Photo library | The camera is granted (now or before), the flow opens with saving to the library on and the library has not been asked for | A saving the user may switch turns off, and the flow goes on to the camera |

The introduction walks through every access the flow needs that has no answer yet: a camera granted before the flow
opened still gets the location and the library steps that are due, and a refused camera gets neither. The camera starts
behind the location and library steps, and while a step is on screen nothing else in the flow brings a system request.
At the accessibility text sizes the footnote scrolls with the page.

`.off` turns the introduction off: the system asks for the camera as soon as the flow opens, for the location right
after the camera is granted (unless `photoLocation` is `.appRequestsAccess` or `.off`), and for the photo library
when a save first needs it. An app that asks for the location itself keeps the introduction and sets
`photoLocation = .appRequestsAccess`.

A camera that cannot run (no camera, denied, restricted) says so in the viewfinder, with a button to the app's page
of Settings where that helps, and the flow stays open: the user leaves with the cross or adds photos from the library.

### Location

Like the stock Camera, the flow writes where each camera photo was taken into the photo by default
(`configuration.photoLocation = .automatic`): the GPS dictionary of the file, and for a photo saved to the photo library
the location of the asset. While the output keeps the metadata, the Live Photo movie carries it too, as QuickTime
metadata (`com.apple.quicktime.location.ISO6709`). The flow follows the location with Core Location at the best accuracy
while the camera is on screen and the app is in the foreground. A photo takes the latest location if it is valid and at
most 60 seconds old. With Precise Location off, a photo records the approximate location (about 5 km off) while it is at
most 20 minutes old, as Core Location updates it a few times an hour, with its accuracy as `GPSHPositioningError`. With
no such location, or without access, the photo is taken at once without one: the shutter never waits for a location.

The flow asks for when-in-use access in its introduction, on a step after the camera's (see Onboarding). A request
made while the app is not in use is asked again when the app comes back. Three choices:

| `photoLocation` | The photos record their location | Who asks for access |
|---|---|---|
| `.automatic` (default) | Yes | The flow, while the user has not answered |
| `.appRequestsAccess` | Yes, while the app has access | The app, before it opens the flow. The flow never asks. |
| `.off` | No | Nobody |

`photoLocation` is about the photos the camera takes. A photo picked from the library keeps the location of its file,
where the system picker hands one over, whatever `photoLocation` says: only an output that strips the metadata takes it
out. A flow whose photos cannot carry a location, because its output strips the metadata and it never saves to the photo
library, treats `photoLocation` and `photoDirection` as off: it never asks for access, follows neither the location nor
the compass and calls no `locationProvider`. A RAW (DNG) photo comes without GPS, since ImageIO cannot write a DNG, and
its asset gets the location all the same when it is saved to the photo library.

An app that follows the location itself passes a `locationProvider`, called at every shutter release, in place of the
flow's own location. The flow still asks for access unless `photoLocation` is `.appRequestsAccess`, and a provider
with `.off` stops the program. The provider's location counts as the flow's own does, while it is valid and at most 60
seconds old, or 20 minutes for an approximate one, so the app keeps its location up to date while the flow is on
screen:

```swift
import CameraFlow
import CoreLocation
import SwiftUI

/// The location the app follows itself while it has access, for its own screens and for the photos of the flow.
@MainActor
final class AppLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    /// The latest fix while the app follows the location.
    var latestFix: CLLocation? {
        manager.location
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            manager.stopUpdatingLocation()
        }
    }
}

@MainActor
func makeFlow(location: AppLocation, onDone: @escaping ([CameraFlowPhoto]) -> Void) -> some View {
    CameraFlowView(locationProvider: { location.latestFix })
        .onCameraFlowFinish(perform: onDone)
        .onCameraFlowCancel { onDone([]) }
}
```

Core Location calls `locationManagerDidChangeAuthorization(_:)` when the manager is created and whenever the access
changes, the answer to the flow's own request included, so the location updates from the moment the user grants it.

### Direction of the camera

`configuration.photoDirection = .recorded` (default `.off`) writes the direction the camera pointed in at the shutter
into the GPS dictionary of the photo: `GPSImgDirection` in degrees from north, also as `GPSDestBearing`, with the
reference "T" for the true north where Core Location knows it and "M" for the magnetic north otherwise. Core Location
knows the true north from the location, which the compass follows only where the photos record their location (not
`.off`) and the user granted access: with `photoLocation = .off` the direction is magnetic. It comes from `CLHeading`
and is the direction the back of the phone faces, in every way the phone is held, not the direction of movement
(`CLLocation.course`, written apart as `GPSTrack`). A reading counts when it is valid, at most 45 degrees off and at
most 5 seconds old, and every sample of the compass counts, so a phone held still on a tripod or under the self-timer
records its direction. Without a reading the photo is taken and handed over without a direction: the shutter never
waits for the compass, and the flow never shows the calibration screen. A photo without a location records the
direction alone. The direction asks for no access of its own and leaves the modes of `photoLocation` as they are. Like
the location, it does not reach a RAW file or a file whose metadata the output strips, and Photos shows no direction
for a saved asset.

### Values that stop the program

The flow checks its configuration when a `CameraFlowView` or a `CameraFlowViewController` is created, and stops the
program with a message (a precondition, in release builds too) on a value no flow can honour:

- a `photoLimit` of `.maximum(n)` below 1;
- a `.longSide(maximum:)` below 1, in the output, in `libraryOutput` or in a quality level, and a compression quality
  outside 0...1;
- a `camera.zoomFactor` or a `camera.exposureBias` value that is not a finite number;
- a RAW `camera.photoFormat` value with an output, or a quality the app fixed, that encodes the photos again or strips
  their metadata;
- an album name that is blank;
- a `settingsMemory` suite that `UserDefaults(suiteName:)` cannot open: an empty name, the app's own bundle identifier
  or the global domain;
- a `locationProvider` with `photoLocation = .off`.

When it opens, the flow also stops the program on a usage description it needs and the app lacks (see Info.plist
keys). An app that builds the configuration from values of its own users or of a server, such as a photo limit or an
album name, checks them before it passes them.

A configuration changed by the SwiftUI modifiers below is checked again when the flow starts, with the same rules, and
a `CameraFlowView` whose flow starts without `onCameraFlowFinish` and `onCameraFlowCancel` stops the program then. A
running flow whose latest view has lost the action of an event stops the program when that event comes.

## SwiftUI modifiers

In SwiftUI the flow is a `CameraFlowView`, created with a configuration, or with the default one as `CameraFlowView()`,
and an optional `locationProvider`. Modifiers give the flow its actions and set some properties of the configuration on
top of the one the view is created with:

```swift
import CameraFlow
import SwiftUI

struct AddPhotoButton: View {
    @State private var isFlowPresented = false
    @State private var photos: [CameraFlowPhoto] = []
    let configuration: CameraFlowConfiguration

    var body: some View {
        Button("Add photo") {
            isFlowPresented = true
        }
        .cameraFlowCover(isPresented: $isFlowPresented) {
            CameraFlowView(configuration: configuration)
                .cameraFlowPhotoLimit(.maximum(5))
                .cameraFlowLibraryPickerEnabled(false)
                .cameraFlowLanguage(.specific(Locale.Language(identifier: "uk")))
                .onCameraFlowFinish { finished in
                    isFlowPresented = false
                    photos.append(contentsOf: finished)
                }
                .onCameraFlowCancel { isFlowPresented = false }
        }
    }
}
```

| Modifier | What it sets |
|---|---|
| `cameraFlowLanguage(_:)` | `configuration.language` |
| `cameraFlowPhotoLimit(_:)` | `configuration.photoLimit` |
| `cameraFlowLibraryPickerEnabled(_:)` | `configuration.isLibraryPickerEnabled` |
| `cameraFlowPhotoLibrarySaving(_:)` | `configuration.photoLibrarySaving`, as a whole |
| `cameraFlowPhotoLocation(_:)` | `configuration.photoLocation` |
| `cameraFlowPhotoDirection(_:)` | `configuration.photoDirection` |
| `cameraFlowOutput(_:)` | `configuration.output`, as a whole |
| `onCameraFlowFinish(perform:)` | the action that receives the accepted set |
| `onCameraFlowCancel(perform:)` | the action that hears the user leave without a set |
| `onCameraFlowPreferencesChange(perform:)` | the action that receives the user's choices |

The rules:

- The configuration the view is created with is the base. A modifier sets one property of it, as an assignment does,
  and every property no modifier sets keeps its value. The rest of the configuration, such as the camera and the
  quality, has no modifier.
- Every event has one receiver, the action of the modifier nearest to the view. As with SwiftUI's own actions, the
  flow calls the actions of the latest update of its view, not the ones it started with.
- A flow needs `onCameraFlowFinish` and `onCameraFlowCancel` for as long as it runs: a flow that starts without them
  stops the program. `onCameraFlowPreferencesChange` is optional.
- A modifier applies to every `CameraFlowView` inside the view it is applied to. Where a property or an action is set
  more than once, the modifier nearest to the flow's view wins.
- The cover carries the modifiers of the flow from the view that presents it into its content, as `fullScreenCover`
  carries the environment, and the modifiers inside `content` win over them. It carries no other environment value.
- The flow reads the configuration with the modifiers' properties once, when it starts. A later change does not
  reconfigure a flow that runs, also when its view comes back after a screen the app presented over it. As for the
  configuration, the texts on the screen follow the latest language, while the Camera Control's lens picker keeps the
  one the flow started with.
- The view checks the configuration it is created with, and the flow checks the configuration with the modifiers' values
  again when it starts, with the same rules (see Values that stop the program).
- `CameraFlowViewController`, for UIKit, takes its configuration and closures from its initializer: no modifier reaches
  its flow.

## The camera

- **Shutter.** It keeps up with quick taps as the stock camera does. Each photo is taken at the best quality the
  camera has, with responsive capture and fast capture prioritization where the camera offers them, and the next tap is
  taken as soon as the camera is ready for it. Photos reach the set and the app in the order they were shot.
  Photos still on their way count against `photoLimit`, and the review, the check mark and the library wait for them.
  While the camera is busy the shutter takes no tap: it is dimmed during a long capture and shows a spinner while the
  camera processes. It takes photos only while the camera runs. A photo whose Live Photo movie or Dual Capture circle
  fails is handed over without it, with a notice such as "Photo taken without Live Photo". The shutter refuses a photo
  with less than about 100 MB of free storage ("Not enough storage"), and a write that fails for want of room says
  the same.
- **Focus and exposure.** A tap focuses and exposes at a point, and both hold until the picture changes a lot: the
  camera then goes back to focusing and exposing by itself. A drag beside the reticle changes the exposure. Touching and
  holding the viewfinder locks the focus and the exposure at the point (AE/AF Lock): as in the stock camera, the lock
  takes a second after the long press began, once the camera has settled, and the stock AE/AF LOCK badge shows. A camera
  that can lock only the exposure at a point, such as a front camera with a fixed focus, locks the exposure alone and
  shows AE LOCK, and one that can lock only the focus shows AF LOCK. The exposure bias still changes under the lock. A
  tap elsewhere, another lens or camera, and the camera stopping end it.
- **Flash.** In Auto the Flash indicator turns yellow while the scene would fire the flash for the next photo, at the
  quality that photo is taken with: the best for HEIF and JPEG, balanced for RAW. It follows a change of the camera and
  of the format. While the flash cannot fire, because the device is too hot or the battery too low, the indicator shows
  a bolt with a warning, photos go without the flash, and a tap explains why in the stock words. A camera without a
  flash, such as the back camera of an iPad, dims the Flash indicator, tile and sub-panel and keeps the chosen mode for
  a camera that has one. The front camera's screen flash is offered wherever the camera offers it.
- **Zoom.** The lens buttons, the zoom dial and a pinch zoom as far as the system's recommended zoom range. A camera
  with an ultra wide lens switches to it at close range by itself, which is the stock automatic macro. Lens
  Correction is on where the camera supports it, as in the stock camera, so a photo can frame slightly differently
  from the preview.
- **Live Photo.** In 4:3 and HEIF only, not with RAW, and its movie has no sound.
- **RAW.** Apple ProRAW, as a DNG, on the cameras that have it (see Output for what the output must allow).
- **Dual Capture.** The second camera in a circle of the viewfinder, on a device that runs the back and the front
  camera at the same time. The flip button swaps the two, and a photo comes with a copy that has the circle's picture
  composited in at the place and the size the viewfinder showed it (`markedUp`). The pair may offer less than one
  camera alone, such as no Live Photo or no RAW: a chosen setting it lacks is left out while the circle is on, with a
  notice, and comes back with it off. When the device must cool down it turns the second camera off.
- **Front camera.** Its photos are saved unmirrored, as the stock camera saves them, alone and in Dual Capture, both
  the photo and the front camera's picture in the circle. The circle of a copy sits over the part of the picture it
  covered in the viewfinder, so for a front-camera photo it lands on the other side than on the mirrored screen.
- **Changes during a photo.** A flip or a switch of Dual Capture tapped while a photo is on its way waits for it, and
  the photo is kept. A shutter tap during a change of the camera takes its photo once the new camera is ready. A
  device with a camera on one side only opens on that camera and has no flip button.
- **Hardware buttons.** From iOS 17.2 a press of a volume button or a full press of the Camera Control takes a photo,
  on release as the stock camera does, while the flow takes photos; the rest of the time the buttons are the system's
  again. On iOS 18 and newer, on an iPhone with the Camera Control, the Camera Control offers Exposure (only while the
  user may change the exposure), Zoom and Cameras, and works while Dual Capture runs where the system supports it.
- **Pauses.** Another app using the camera, iPad multitasking, the app going to the background and a device that must
  cool down pause the camera with a notice, and it comes back by itself. Under serious system pressure the preview runs
  at 15 to 20 frames a second, which puts off the pause. A camera that stopped with an error says "Camera unavailable"
  in the flow's language, with "Try Again" where a new start can help, and the system's error text goes to the log.
- **In the background.** A photo being processed, a save and the hand-over go on when the app leaves the foreground,
  for as long as the system gives the app (`ProcessInfo.performExpiringActivity`).
- **The look.** The glyphs are public SF Symbols drawn by the running iOS, so each iOS version shows its own designs,
  and the package draws its own aspect ratio, timer and control panel glyphs. The glass of the controls is the
  system's Liquid Glass on iOS 26 and newer and a blurred, tinted imitation on iOS 17 and 18. No Apple artwork ships
  with the package.

## Markup

The review's Markup draws on a photo with the system's own markup. On iOS 26 and newer it is PaperKit, with
PaperKit's first feature set: strokes, shapes, text, images and stickers from the "+" of the tool picker, without the
loupes and the links, which a saved drawing does not render. Features a later iOS adds to PaperKit are not offered. On
iOS 17 and 18 it is PencilKit, which draws strokes only. A drawing is shown and written with the engine that made it.

On iPad, Apple Pencil draws, and a finger draws too unless the system's Only Draw with Apple Pencil setting is on,
which the Draw with Finger switch of the tool picker changes: with it on, a finger selects on iOS 26 and newer and does
nothing on iOS 17 and 18. On iPhone a finger always draws. When the iPad turns or its window changes size during
Markup, the drawing stays over the photo: the canvas keeps its size and is shown scaled, ink and handles included.

## Localization

The package ships its texts in 37 languages:

`ar`, `bg`, `cs`, `da`, `de`, `el`, `en`, `es`, `es-419`, `et`, `fi`, `fr`, `he`, `hi`, `hr`, `hu`, `id`, `it`, `ja`,
`ko`, `lt`, `lv`, `nb`, `nl`, `pl`, `pt-BR`, `pt-PT`, `ro`, `ru`, `sk`, `sv`, `th`, `tr`, `uk`, `vi`, `zh-Hans`,
`zh-Hant`.

The texts the stock camera has are its own words in each language, and so are its forms: the zoom factor reads "x2"
in the Spanish of Spain, "2 ×" in Russian and Norwegian and "× 2" in Lithuanian, the labels the stock camera spaces
out are set solid in Arabic, Hindi and Thai as there, and the self-timer counts in the digits of the locale.

By default (`configuration.language = .system`) iOS picks the language of a package from the languages the host app
declares. An app that is not localized into a language shows the flow in English, whatever the package ships.
Declare the languages in one of these ways:

- localize the app itself into them;
- list them under `CFBundleLocalizations` in the app's Info.plist;
- set `CFBundleAllowMixedLocalizations` to true in the app's Info.plist.

Latin American Spanish needs the app to declare `es-419` too: an app that declares only `es` gets Spain's texts
(Ajustes, Hacer foto) on a Latin American device.

An app with a language setting of its own passes it instead:
`configuration.language = .specific(Locale.Language(identifier: "uk"))`. The flow then writes its controls, notices,
alerts, introduction and accessibility labels in that language, with its numbers, plural forms and capitals, and lays
its introduction out in its direction, whatever the device's language and the app's declared languages are. VoiceOver
speaks the flow's labels in that language while the flow is on screen, which sets the language of the whole app for that
time. A specific language is matched the way the system matches the languages of a device: to the closest one the
package has (`uk-UA` to `uk`, `pt` to `pt-BR`, `es-MX` to `es-419`, `zh-TW` to `zh-Hant`), and to English when there is
none. The plural forms and the capitals follow the language of the texts, and the numbers keep the digits and the region
of the language as it was passed, so a language without texts of its own gets English texts with its own numbers.
`CameraFlowLanguage.supportedLanguages` lists the 37.

iOS also offers Bengali, Catalan, Gujarati, Kannada, Kazakh, Malay, Malayalam, Marathi, Odia, Punjabi, Slovenian,
Tamil, Telugu and Urdu, which the package does not ship. In these the flow is English, laid out left to right even in
Urdu, with the numbers of the language. Hong Kong Chinese and Cantonese get the Traditional Chinese of Taiwan,
Canadian French the French of France, and US Spanish the Latin American texts.

In a right-to-left language the review and the Markup controls mirror, while the camera controls and the bottom bar keep
the stock camera's order. The system's own screens follow the language of the app and the device, never `language`: the
photo picker, the alerts that ask for the camera, the location and the photo library (their texts are the usage
descriptions of the app's Info.plist), the markup tools of PencilKit and PaperKit, the exposure and zoom sliders of the
Camera Control overlay and the Settings app. The overlay's lens picker is the flow's own and follows `language`.

## Accessibility

- **VoiceOver.** Every control has a label and a value in the flow's language. The exposure, the lens buttons and the
  mode switch are adjustable: the lens buttons step through the lenses, every whole factor and the end of the digital
  zoom. Notices, failures, the self-timer, the growing set and the hand-over are announced. The focus moves into the
  control panel as it opens, to a sub-panel's title, back to its tile and to Camera controls as the panel closes. An
  action on the viewfinder locks and unlocks what the camera can lock and names it, and the lock is announced as it
  takes and as it ends. Magic Tap takes a photo, and the escape gesture closes what is on top.
- **Keyboard.** Escape works as the cross, closes the control panel, takes a sub-panel back to the tiles and cancels
  Markup. Return works as the check mark, as Markup's Done and as Continue in the introduction, and Command-Z and
  Shift-Command-Z undo and redo in Markup.
- **Text size.** The flow's own texts follow Dynamic Type: the introduction, the failure message, the notices (up to
  the largest size short of the accessibility sizes, wrapping to two lines on a phone and to three in a 320 point
  window), the review and Markup. The camera's chrome keeps the stock camera's fixed sizes and offers the Large Content
  Viewer instead: at an accessibility text size, a long press on a top bar item, the flip, a lens button, a tile, a
  sub-panel option or a button of the bars shows it large. The top bar items, a sub-panel's Back and Markup's undo and
  redo take a touch 44 points around them.
- **Reduce Motion.** The capture flight is left out, and the badge of the set fades instead of bumping. The control
  panel fades in place at the size of what it shows while its contents cross-fade, and the lens row, the zoom dial and
  the shutter take the places a sub-panel gives them at once. The zoom dial and its value, the lens buttons, the
  self-timer digits, the focus reticle and the Dual Capture circle fade or change in place instead of moving. The items
  of the top bar take their places at once, and an indicator that comes or goes only fades. The thumb of the mode switch
  does not stretch, and the steps of the introduction fade from one to the next.
- **Display settings.** Bold Text, Increase Contrast and Button Shapes are honoured. With Differentiate Without Color
  the Dual Capture indicator shows an empty frame while the circle is off, the Save indicator dims while saving is off,
  and the Auto flash is outlined while the flash would not fire and filled when it would.
- **Voice Control** answers to the visible words of the controls.

## Privacy

The package ships `PrivacyInfo.xcprivacy`. It declares no tracking, no collected data, and two required-reason APIs:
`UserDefaults` (reasons `CA92.1` and `1C8F.1`), where the flow remembers the user's settings, and the free disk space
(`E174.1`), which the shutter reads before a photo. The usage descriptions and the privacy policy are the app's.

The location the flow reads, precise or approximate, stays on the device: it is written into the user's own photo files,
which are handed to the app, and into the user's photo library. The package sends nothing anywhere, so it declares no
collected location. An app that uploads the photos, or reads their GPS, collects the location and declares it in its own
manifest: `NSPrivacyCollectedDataTypePreciseLocation`, and `NSPrivacyCollectedDataTypeCoarseLocation` where users may
allow approximate location. A photo picked from the library keeps the location of its file, where the system picker
hands one over, whatever `photoLocation` says: only an output that strips the metadata takes it out (see Location). Core
Location is not a required-reason API. The location, the compass and the device motion stop while the app is in the
background.

The package logs through `os.Logger` (see Troubleshooting) and shows file paths, picked file names and photo metadata
values there as private data only, and its own error texts hold no path.

## Source stability

CameraFlow follows semantic versioning. A 1.x release adds API and never changes or removes any. It adds no case to a
public enum, except to the three marked `@nonexhaustive`: `CameraFlowPhoto.Source`, `CameraFlowPhotoLibrarySaveFailure`
and `CameraFlowPhotoLibraryError`. A `switch` over one of these three needs `@unknown default`. A `switch` over any
other public enum stays exhaustive in every 1.x release: a new value comes as a new type or property, never as a new
case. The stored coding of `CameraFlowPreferences` stays readable by every 1.x release. The `@_spi(Testing)` fixtures
are outside this promise and may change in any release.

## Testing support

`@_spi(Testing) import CameraFlow` opens the fixtures the Example and its UI tests use: a simulated camera, the access
it finds and photos it takes by itself.

```swift
@_spi(Testing) import CameraFlow

func makeUITestConfiguration() -> CameraFlowConfiguration {
    var configuration = CameraFlowConfiguration()
    configuration.camera.usesSimulatedCamera = true
    configuration.camera.simulatedScene = .color(red: 0.1, green: 0.4, blue: 0.8)
    configuration.camera.automaticCaptureCount = 2
    configuration.simulatedAccess = .cameraNotAsked
    return configuration
}
```

In the iOS Simulator the flow always runs over the simulated camera. The simulated camera's access answers at once,
without a system alert. With a "not asked" `simulatedAccess`, such as `.cameraNotAsked`, the photo library and the
location are simulated too. With the default `.granted` and with `.cameraDenied` they are the system's, with their
real requests: set `photoLocation = .off` and keep saving off, or take a "not asked" value, to keep system alerts out
of a UI test. A simulated photo is a flat picture of the scene colour in a file shaped like a device's, encoded off the
main actor. A simulated RAW photo is that same processed file marked RAW, since ImageIO cannot write a DNG, and the
simulated Live Photo movie is an empty stand-in that the system photo library refuses.

## Running the Example

Open `Example/CameraFlowExample.xcodeproj`, pick the `CameraFlowExample` scheme, set your team under Signing &
Capabilities for a device, and run. The bundle identifiers end with the team identifier
(`SAMPLE_CODE_DISAMBIGUATOR`, as in Apple's sample code), so they are your own; a build without a team keeps
`com.majestic-codes.CameraFlowExample`. From the command line, on a Mac that may register the identifier with your
team:

```sh
xcodebuild -project Example/CameraFlowExample.xcodeproj -scheme CameraFlowExample \
  -destination 'generic/platform=iOS' \
  DEVELOPMENT_TEAM=YOURTEAMID -allowProvisioningUpdates build
```

The example app opens the flow through SwiftUI or through UIKit and lists the photos it kept in this launch. It
takes the files of a set over into `Documents/Captures` and `Documents/Edited`, keeping the original beside the copy
with a drawing to compare the two, where an app would keep `result` and delete the rest, and every launch removes
the files of the one before. Unlike the package's default, it opens with saving to the photo library on and
switchable, and with the quality row. It logs every photo, its files and every `CameraFlowPreferences` the flow
reports, and passes the last stored preferences to the next flow.

Launch arguments put it in a fixed state. Every argument that starts with `-cameraFlow` must be one of the table's,
given once. A misspelled or repeated argument, an invalid value (such as an exposure that is not a number or a scene
channel outside 0 to 255), a sub-panel of a setting the flow does not offer, `-cameraFlow` with `-cameraFlowUIKit`,
and more than one of `-cameraFlowNoLibrarySave`, `-cameraFlowSaveToLibrary` and `-cameraFlowSaveToAlbum` stop the
launch with the error on screen.

| Argument | Effect |
|---|---|
| `-cameraFlow` | Opens the flow at launch. |
| `-cameraFlowUIKit` | Opens it at launch through a `CameraFlowViewController` presented from the example's own controller. |
| `-cameraFlowResetState` | Removes what the example stored and what the flow remembers from the defaults first. |
| `-cameraFlowNoLibrary` | Turns the photo library picker off (`isLibraryPickerEnabled = false`). |
| `-cameraFlowLimit 3` | Limits the set to that many photos. |
| `-cameraFlowSinglePhoto` | Ends the flow by itself after one photo (`completion = .afterOnePhoto`). |
| `-cameraFlowLive` | Makes Live Photo adjustable. |
| `-cameraFlowRAW` | Opens with the RAW format. |
| `-cameraFlowAspect 4:3\|16:9\|1:1` | Sets the aspect ratio. |
| `-cameraFlowTimer 0\|3\|5\|10` | Sets the timer. |
| `-cameraFlowExposure 0.7` | Sets the exposure bias. |
| `-cameraFlowDualCamera` | Opens with the second camera's circle on, where the device has it and no remembered choice turns it off. |
| `-cameraFlowDualCameraSwapped` | The same, with the front camera in the viewfinder. |
| `-cameraFlowLock flash,live,aspect,timer,exposure,format,dual,save,quality` | Fixes the named settings to their values. |
| `-cameraFlowSize standard\|1024` | Limits the long side of the output. |
| `-cameraFlowFormat jpeg:0.8\|heic:0.7` | Re-encodes the output at that quality. |
| `-cameraFlowStripMetadata` | Strips the metadata of the output. |
| `-cameraFlowLibraryOriginal` | Keeps the picks as the library gave them (`libraryOutput = .separate(CameraFlowOutput())`). |
| `-cameraFlowQuality high\|medium\|low` | Sets the quality the flow opens with, unless a stored choice says otherwise. |
| `-cameraFlowQualityLevels medium=2048:jpeg:0.8,low=1280:jpeg:0.6` | Says what the medium and the low quality give: the long side, and `jpeg` or `heic` with its quality, or the long side alone for the output's format. |
| `-cameraFlowNoLibrarySave` | Switches saving to the photo library off. |
| `-cameraFlowSaveToLibrary` | Switches saving on, into the library, as the example opens anyway. |
| `-cameraFlowSaveToAlbum Name` | Switches saving on, into that album. |
| `-cameraFlowSaveMoment whenSetAccepted\|afterEachPhoto` | Sets when the camera photos are saved (`photoLibrarySaving.moment`). |
| `-cameraFlowNoLocation` | Turns the location of the photos off (`photoLocation = .off`). |
| `-cameraFlowDirection` | Records the direction of the camera (`photoDirection = .recorded`). |
| `-cameraFlowLanguage uk` | Writes the flow's texts in that language (`language = .specific`). |
| `-cameraFlowNoPreferences` | Passes no stored preferences to the flow. |
| `-cameraFlowNoMemory` | Switches the flow's own memory of the settings off. |
| `-cameraFlowNoOnboarding` | Turns the introduction off (`onboarding = .off`). |
| `-cameraFlowAccess camera\|library\|location\|locationDenied\|all\|locationAndLibrary\|libraryAlone\|denied` | Opens the simulated camera with access not asked for yet: the camera; the camera and the library; the location alone, granted or refused when asked; the camera, the location and the library; the location and the library of a granted camera; the library alone. `denied` is a camera refused when asked. The simulated access answers without a system alert. |
| `-cameraFlowSimulated` | Uses the simulated camera on a device too. |
| `-cameraFlowScene 15,11,9` | The colour of the simulated camera, each channel from 0 to 255. |
| `-cameraFlowAutoCapture 2` | Takes that many photos once the camera runs. |
| `-cameraFlowRotation portrait\|left\|right\|down` | Turns the simulated camera's device. |
| `-cameraFlowStartFailures 1` | Makes the simulated camera fail to start that many times. |
| `-cameraFlowPanel` | Opens the control panel. |
| `-cameraFlowSubPanel flash` | Opens the sub-panel of one setting: `flash`, `live`, `aspect`, `timer`, `exposure`, `format`, `dualCamera` or `librarySave`. |
| `-cameraFlowDial` | Opens the zoom dial, which stays open until the first touch. |

## Development

From the repository root, with Xcode 27 or newer and SwiftLint 0.63.2:

```sh
swift build
swift test
xcodebuild build-for-testing -scheme CameraFlow -destination 'generic/platform=iOS Simulator' \
  -skipMacroValidation CODE_SIGNING_ALLOWED=NO
swiftlint lint --strict
```

These are the commands CI runs on every pull request: the first three on macOS with Xcode 27.2, SwiftLint on Linux.
`swift build` and `swift test` build the package for macOS and run its unit tests there, with Swift Testing against a
fake camera. They need Xcode 27: its `swift test` builds with Swift Build, which compiles `Localizable.xcstrings`,
while Xcode 26's copies the catalog uncompiled and the test run stops. The compiler skips the code inside
`#if os(iOS)` on macOS, the screens, the views and the device camera among it: `xcodebuild build-for-testing` compiles
the whole package and its tests for iOS without a simulator, a test run or signing.

The documentation is the DocC catalog `Sources/CameraFlow/CameraFlow.docc` with the `///` comments of the public API,
which the Swift Package Index builds (`.spi.yml`). It builds without a warning, and a link to a symbol that does not
exist fails the build:

```sh
xcodebuild docbuild -scheme CameraFlow -destination 'generic/platform=iOS Simulator' \
  -skipMacroValidation CODE_SIGNING_ALLOWED=NO OTHER_DOCC_FLAGS=--warnings-as-errors
```

The package tests also run on an iOS simulator, which runs the iOS-only code under test. Turn parallel testing off
there: parallel HEIC encodes hang in the simulator.

```sh
xcodebuild test -scheme CameraFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO
```

The Example and its UI tests build without a simulator and without signing, and CI does not build them:

```sh
xcodebuild build-for-testing -project Example/CameraFlowExample.xcodeproj -scheme CameraFlowExample \
  -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO
```

The UI tests of the Example run on a simulator, one at a time, by hand:

```sh
xcodebuild test -project Example/CameraFlowExample.xcodeproj -scheme CameraFlowExample \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -parallel-testing-enabled NO
```

Name any iPhone simulator that `xcrun simctl list devices available` lists. The UI tests pin the app to English (US),
and the Ukrainian ones to Ukrainian (Ukraine), so they pass on a simulator in any language, but
`CameraFlowLibraryUITests` finds the system's photo picker by its English labels: run that class on a simulator in
English. [CONTRIBUTING.md](CONTRIBUTING.md) lists what a pull request needs and the checks before a release, among them
the package tests and `CameraFlowMarkupUITests` on an iOS 18.6 simulator, which has no PaperKit.

## Troubleshooting

The package logs through `os.Logger` under the subsystem `CameraFlow`, with one category for each part, such as
`CameraSessionModel` or `PhotosLibraryWriter`. A missing location, a photo that was not saved, a camera that did not
start or a Camera Control without controls each leave a line there. Xcode's console shows the lines while the app runs
from Xcode; in the Console app, pick the device and search for `subsystem:CameraFlow`.

## Known limitations

- Photo mode only: no video, Portrait, Pano, Night mode, Photographic Styles or spatial photos.
- The camera takes 12 MP photos where it has that size, and its largest size otherwise: no 24 MP or 48 MP, and no
  deferred photo processing.
- Live Photo works in 4:3 only, not together with RAW, and its movie has no sound.
- RAW (Apple ProRAW, a DNG) is offered only where the camera has it and the output takes a DNG as it is, under the
  quality `high`. A RAW photo file comes without GPS (ImageIO cannot write a DNG); saved to the photo library, its asset
  gets the location all the same.
- The second camera's circle needs a device that runs the back and the front camera at the same time. The pair may
  offer less than one camera alone, such as no Live Photo or no RAW.
- The flow finds its camera among the triple, the dual wide, the dual and the wide angle cameras of each side: a
  camera that AVFoundation offers only as another type is not used.
- On iPhone the interface is portrait: single elements turn as the phone rotates, the layout does not. On iPad the
  interface turns with the device and keeps the same arrangement, and the camera pauses while other apps share the
  screen.
- In a right-to-left language the camera controls keep their left-to-right places, as the stock camera's do. The
  review, Markup, the introduction and the system alerts follow the language.
- The markup offers strokes only on iOS 17 and 18, where PaperKit does not exist.
- Saving to an album fails under limited library access, and the photo is not saved elsewhere instead.
- A photo saved right after its shot (`.afterEachPhoto`) keeps no drawing in the library, and leaving the flow
  does not take it out of the library.
- A Live Photo with a drawing is saved to the library as a still with the drawing as its edit, so Revert in Photos
  gives the still photo, not the Live Photo.
- `photoLocation = .off` covers the camera photos: a photo picked from the library keeps the location of its file, where
  the system picker hands one over, unless the output strips the metadata.
- `language` covers the flow's own texts only: the system screens it presents follow the app and the device.
- Each flow reads the device motion through a `CMMotionManager` of its own, beside any the app runs, though Apple
  advises one per app: it runs only while the camera of the flow is open and the app is in the foreground, and an app
  cannot pass its own.
- Present the flow over the content (`cameraFlowCover`, `CameraFlowViewController`), not inside a tab or a navigation
  stack: a flow whose view is taken away deletes its set, and a view that comes back starts a new flow.

## Contributing

Bug reports and pull requests are welcome: [CONTRIBUTING.md](CONTRIBUTING.md) says what a pull request needs. A
security vulnerability is reported privately, as [SECURITY.md](SECURITY.md) describes.

## License

MIT. See [LICENSE](LICENSE).
