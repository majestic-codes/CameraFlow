# SwiftUI modifiers

Use the flow in SwiftUI: a configuration as the base, and modifiers that set its properties and give the flow its
actions.

## Overview

In SwiftUI the flow is a ``CameraFlowView``, created with a ``CameraFlowConfiguration`` or with the default one, and
presented with ``SwiftUICore/View/cameraFlowCover(isPresented:onDismiss:content:)``. Modifiers give the flow its actions
and set properties of the configuration, on the view, on a view around it, or around the view that presents the cover:

```swift
.cameraFlowCover(isPresented: $isFlowPresented) {
    CameraFlowView(configuration: configuration)
        .cameraFlowPhotoLimit(.maximum(5))
        .cameraFlowLibraryPickerEnabled(false)
        .cameraFlowLanguage(.specific(Locale.Language(identifier: "uk")))
        .onCameraFlowPreferencesChange { preferences in store(preferences) }
        .onCameraFlowFinish { photos in
            isFlowPresented = false
            keep(photos)
        }
        .onCameraFlowCancel { isFlowPresented = false }
}
```

### The configuration is the base

The configuration the view is created with is the base, the default one where the view gets none. Each modifier sets
one property of it to the value it is given, as an assignment to that property does, and every property no modifier
sets keeps the value of the configuration:

| Modifier | Property it sets |
|---|---|
| ``SwiftUICore/View/cameraFlowLanguage(_:)`` | ``CameraFlowConfiguration/language`` |
| ``SwiftUICore/View/cameraFlowPhotoLimit(_:)`` | ``CameraFlowConfiguration/photoLimit`` |
| ``SwiftUICore/View/cameraFlowLibraryPickerEnabled(_:)`` | ``CameraFlowConfiguration/isLibraryPickerEnabled`` |
| ``SwiftUICore/View/cameraFlowPhotoLibrarySaving(_:)`` | ``CameraFlowConfiguration/photoLibrarySaving`` |
| ``SwiftUICore/View/cameraFlowPhotoLocation(_:)`` | ``CameraFlowConfiguration/photoLocation`` |
| ``SwiftUICore/View/cameraFlowPhotoDirection(_:)`` | ``CameraFlowConfiguration/photoDirection`` |
| ``SwiftUICore/View/cameraFlowOutput(_:)`` | ``CameraFlowConfiguration/output`` |

The saving to the photo library and the output are replaced as a whole: the value a modifier gets is the whole
property, not a change to the configuration's. Everything else, such as the camera, the quality, the remembered
settings and the introduction, is set in the configuration only.

### The actions

``SwiftUICore/View/onCameraFlowFinish(perform:)`` receives the photos of the accepted set, once, and the app owns their
files from then on. ``SwiftUICore/View/onCameraFlowCancel(perform:)`` hears the user leave without a set, and
``SwiftUICore/View/onCameraFlowPreferencesChange(perform:)`` receives the user's choices after every change. Every event
has one receiver, the action of the modifier nearest to the view, so the files of an accepted set reach one owner.

As with SwiftUI's own actions, such as `onSubmit(of:_:)`, the flow calls the actions of the latest update of its view,
not the ones it started with: a view the app creates again under other modifiers hands them to the flow that runs.

A flow needs a receiver of the set and of the user's exit for as long as it runs: a flow that starts without
``SwiftUICore/View/onCameraFlowFinish(perform:)`` or ``SwiftUICore/View/onCameraFlowCancel(perform:)`` stops the
program, and so does an event whose action the latest view no longer has. The preferences need no receiver. Every
action is called on the main actor.

### Where a modifier applies

A modifier applies to every ``CameraFlowView`` inside the view it is applied to, as the SwiftUI environment does. Where
the same property or the same action is set more than once, the modifier nearest to the flow's view wins.

The cover of ``SwiftUICore/View/cameraFlowCover(isPresented:onDismiss:content:)`` hosts its content in a controller of
its own, and carries the modifiers of the flow into it, as `fullScreenCover` carries the environment: the modifiers
around the view that presents the cover reach the flow, and the ones inside `content` win over them. The cover carries
no other value of the environment.

```swift
Button("Add photo") {
    isFlowPresented = true
}
.cameraFlowCover(isPresented: $isFlowPresented) {
    CameraFlowView()
        .cameraFlowPhotoLimit(.single)
}
.cameraFlowPhotoLimit(.maximum(5))
.onCameraFlowFinish { photos in
    isFlowPresented = false
    keep(photos)
}
.onCameraFlowCancel { isFlowPresented = false }
```

Here the flow holds one photo: the limit inside `content` wins.

``CameraFlowViewController``, the flow for UIKit, takes its configuration and its closures from its initializer, and its
results reach the closures and the delegate. Its flow runs in a hierarchy of its own, which no modifier reaches.

### When the flow reads them

The flow reads the configuration once, when it starts: the configuration and the location provider of the view, and
the properties the modifiers set. A change that comes later, in a value a modifier is given or in the modifiers around
the view, does not reconfigure a flow that runs: the flow keeps the configuration it started with until it ends, also
when a screen the app presented over it leaves and its view comes back. The next flow, such as the one of the next
presentation, reads it again. The actions are the exception the section above describes: the flow calls the latest.

The language follows the latest value too, as for the configuration: the texts on the screen follow the latest
``SwiftUICore/View/cameraFlowLanguage(_:)``, or the latest configuration where no modifier sets it, while the lens
picker of the Camera Control keeps the language the flow started with.

### The checks

The view checks the configuration it is created with when it is created. When the flow starts, the configuration with
the properties the modifiers set passes the same checks again, with the same preconditions: a modifier that makes a
value no flow can honour stops the program then, such as a ``CameraFlowPhotoLimit/maximum(_:)`` below 1, a blank album
name, an output that encodes a RAW photo again, or ``CameraFlowPhotoLocation/off`` for a view created with a
`locationProvider`. The configuration the view is created with passes its own checks first, whatever the modifiers set
over it.

## Topics

### Creating the view

- ``CameraFlowView/init(configuration:locationProvider:)``

### Receiving the results

- ``SwiftUICore/View/onCameraFlowFinish(perform:)``
- ``SwiftUICore/View/onCameraFlowCancel(perform:)``
- ``SwiftUICore/View/onCameraFlowPreferencesChange(perform:)``

### Setting properties of the configuration

- ``SwiftUICore/View/cameraFlowLanguage(_:)``
- ``SwiftUICore/View/cameraFlowPhotoLimit(_:)``
- ``SwiftUICore/View/cameraFlowLibraryPickerEnabled(_:)``
- ``SwiftUICore/View/cameraFlowPhotoLibrarySaving(_:)``
- ``SwiftUICore/View/cameraFlowPhotoLocation(_:)``
- ``SwiftUICore/View/cameraFlowPhotoDirection(_:)``
- ``SwiftUICore/View/cameraFlowOutput(_:)``
