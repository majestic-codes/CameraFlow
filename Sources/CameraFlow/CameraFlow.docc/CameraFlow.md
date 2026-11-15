# ``CameraFlow``

The whole "Add photo" flow of an iOS app: a camera like the stock Photo mode, the photo library, a review of the set
and a markup, handed back to the app as files.

## Overview

The user takes photos with a camera that looks and behaves like the stock Camera's Photo mode, adds photos from the
photo library through the system picker, reviews the set, draws on a photo and accepts the set. The app receives the
photos as files it owns, in the size, the format and with the metadata it asks for.

The camera has the controls of the stock Photo mode: the lens buttons, the zoom dial and a pinch, the flash, Live Photo,
the self-timer, the aspect ratios 4:3, 16:9 and 1:1, HEIF or RAW, the exposure, tap to focus, AE/AF Lock with a touch
and hold, and the second camera in a circle of the viewfinder where the device runs two cameras. The markup offers
PaperKit's strokes, shapes, text, images and stickers on iOS 26 and newer, and PencilKit's strokes on iOS 17 and 18. An
introduction says what each access is for before the system asks for it, the user's settings are remembered between
flows, and the texts come in 37 languages.

CameraFlow runs on iPhone and iPad with iOS 17 or newer. It builds with Xcode 26.2 or newer, with Swift 6.2.3: the Swift
tools version of the package, which its three `@nonexhaustive` enums need, so an older Xcode refuses the package with a
version message.

### Present the flow

In SwiftUI, present a ``CameraFlowView`` with
``SwiftUICore/View/cameraFlowCover(isPresented:onDismiss:content:)`` and give it its actions with modifiers:

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

In UIKit, present a ``CameraFlowViewController``, which dismisses itself when the flow ends:

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

The app's Info.plist describes what the flow asks the system for: `NSCameraUsageDescription` always,
`NSLocationWhenInUseUsageDescription` while the flow asks for the location of the photos, as it does by default
(``CameraFlowPhotoLocation/automatic``), and `NSPhotoLibraryAddUsageDescription`, or `NSPhotoLibraryUsageDescription`
for an album, where the flow may save to the photo library (``CameraFlowPhotoLibrarySaving``). A flow that would ask
without its description stops the program when it starts, and names the key.

### Configure the flow

Everything the flow offers is a property of ``CameraFlowConfiguration``, and the default configuration is a complete
flow. A setting the user may change is a ``CameraFlowSetting``: the value the camera opens with, and whether the user
may change it. The flow remembers the user's choices itself and reports them as ``CameraFlowPreferences``. The output
(``CameraFlowOutput``) is what the app takes at most: the size, the format and the metadata of the files.

In SwiftUI, modifiers set some properties of the configuration over the one the view is created with, such as the
photo limit and the language, and give the flow its actions: see <doc:SwiftUIModifiers>.

### Receive the photos

The flow hands the accepted set over once, as ``CameraFlowPhoto`` values in their order: in SwiftUI to
``SwiftUICore/View/onCameraFlowFinish(perform:)``, in UIKit to `onFinish` or the delegate of
``CameraFlowViewController``. The app owns their files from then on. They sit in a temporary directory, so the app moves the files it keeps,
usually the file of ``CameraFlowPhoto/result``, and deletes the rest:

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

## Source stability

CameraFlow follows semantic versioning. A 1.x release adds API and never changes or removes any. It adds no case to a
public enum, except to the three marked `@nonexhaustive`: ``CameraFlowPhoto/Source``,
``CameraFlowPhotoLibrarySaveFailure`` and ``CameraFlowPhotoLibraryError``. A `switch` over one of these three needs
`@unknown default`. A `switch` over any other public enum stays exhaustive in every 1.x release: a new value comes as a
new type or property, never as a new case. The stored coding of ``CameraFlowPreferences`` stays readable by every 1.x
release. The `@_spi(Testing)` fixtures are outside this promise and may change in any release.

## Topics

### Presenting the flow

- ``CameraFlowView``
- <doc:SwiftUIModifiers>
- ``SwiftUICore/View/cameraFlowCover(isPresented:onDismiss:content:)``
- ``CameraFlowViewController``
- ``CameraFlowViewControllerDelegate``

### Configuring the flow

- ``CameraFlowConfiguration``
- ``CameraFlowSetting``
- ``CameraFlowPhotoLimit``
- ``CameraFlowCompletion``
- ``CameraFlowOnboarding``
- ``CameraFlowLanguage``

### Setting up the camera

- ``CameraFlowInitialState``
- ``CameraFlowFlashMode``
- ``CameraFlowAspectRatio``
- ``CameraFlowTimer``
- ``CameraFlowPhotoFormat``

### Recording the location and the direction

- ``CameraFlowPhotoLocation``
- ``CameraFlowPhotoDirection``

### Shaping the files

- ``CameraFlowOutput``
- ``CameraFlowOutputSize``
- ``CameraFlowOutputFormat``
- ``CameraFlowOutputMetadata``
- ``CameraFlowLibraryOutput``
- ``CameraFlowQuality``
- ``CameraFlowQualityLevels``
- ``CameraFlowQualityLevel``

### Saving to the photo library

- ``CameraFlowPhotoLibrarySaving``
- ``CameraFlowPhotoLibrarySave``
- ``CameraFlowPhotoLibraryAsset``
- ``CameraFlowPhotoLibrarySaveFailure``
- ``CameraFlowPhotoLibraryError``

### Remembering the user's choices

- ``CameraFlowPreferences``
- ``CameraFlowSettingsMemory``

### Receiving the photos

- ``CameraFlowPhoto``
