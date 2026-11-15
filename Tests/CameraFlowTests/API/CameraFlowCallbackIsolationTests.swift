//
//  CameraFlowCallbackIsolationTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import CoreLocation
import CameraFlow
import SwiftUI
import Testing

/// The public screens as a Swift 6 app builds them, compiled in the Swift 6 language mode: with closures written in
/// place over state of the main actor, with the methods of a receiver isolated to the main actor, and with plain
/// closure properties forwarded from the app's own view. The module is imported as an app imports it, so the test
/// reads the public signatures. The check is the compilation: no test calls a closure or expects anything.
@Suite("Callbacks of the public screens")
struct CameraFlowCallbackIsolationTests {
    /// What an app keeps of a flow, on the main actor.
    @MainActor
    private final class Receiver {
        private(set) var photos: [CameraFlowPhoto] = []
        private(set) var preferences: CameraFlowPreferences?
        private(set) var isCancelled = false

        func finish(with photos: [CameraFlowPhoto]) {
            self.photos = photos
        }

        func cancel() {
            isCancelled = true
        }

        func store(_ preferences: CameraFlowPreferences) {
            self.preferences = preferences
        }

        func location() -> CLLocation? {
            nil
        }
    }

    /// Callbacks an app's view got from its parent as plain closures and passes on.
    @MainActor
    private struct ForwardedCallbacks {
        let locationProvider: () -> CLLocation?
        let onPreferencesChange: (CameraFlowPreferences) -> Void
        let onFinish: ([CameraFlowPhoto]) -> Void
        let onCancel: () -> Void
    }

    @Test("Both screens take closures written in place over state of the main actor")
    @MainActor
    func closuresInPlace() {
        let receiver = Receiver()
        _ = CameraFlowView(
            locationProvider: { receiver.location() },
            onPreferencesChange: { receiver.store($0) },
            onFinish: { receiver.finish(with: $0) },
            onCancel: { receiver.cancel() }
        )
        _ = CameraFlowViewController(
            locationProvider: { receiver.location() },
            onPreferencesChange: { receiver.store($0) },
            onFinish: { receiver.finish(with: $0) },
            onCancel: { receiver.cancel() }
        )
    }

    @Test("Both screens take methods isolated to the main actor")
    @MainActor
    func mainActorMethods() {
        let receiver = Receiver()
        let locationProvider: @MainActor () -> CLLocation? = receiver.location
        let onPreferencesChange: @MainActor (CameraFlowPreferences) -> Void = receiver.store
        let onFinish: @MainActor ([CameraFlowPhoto]) -> Void = receiver.finish
        let onCancel: @MainActor () -> Void = receiver.cancel
        _ = CameraFlowView(
            locationProvider: locationProvider,
            onPreferencesChange: onPreferencesChange,
            onFinish: onFinish,
            onCancel: onCancel
        )
        _ = CameraFlowViewController(
            locationProvider: locationProvider,
            onPreferencesChange: onPreferencesChange,
            onFinish: onFinish,
            onCancel: onCancel
        )
    }

    @Test("Both screens take plain closure properties an app forwards")
    @MainActor
    func forwardedClosures() {
        let receiver = Receiver()
        let callbacks = ForwardedCallbacks(
            locationProvider: { receiver.location() },
            onPreferencesChange: { receiver.store($0) },
            onFinish: { receiver.finish(with: $0) },
            onCancel: { receiver.cancel() }
        )
        _ = CameraFlowView(
            locationProvider: callbacks.locationProvider,
            onPreferencesChange: callbacks.onPreferencesChange,
            onFinish: callbacks.onFinish,
            onCancel: callbacks.onCancel
        )
        _ = CameraFlowViewController(
            locationProvider: callbacks.locationProvider,
            onPreferencesChange: callbacks.onPreferencesChange,
            onFinish: callbacks.onFinish,
            onCancel: callbacks.onCancel
        )
    }

    @Test("The modifiers of the flow take closures written in place, methods of the main actor and forwarded closures")
    @MainActor
    func modifierClosures() {
        let receiver = Receiver()
        _ = CameraFlowView { receiver.location() }
            .onCameraFlowPreferencesChange { receiver.store($0) }
            .onCameraFlowFinish { receiver.finish(with: $0) }
            .onCameraFlowCancel { receiver.cancel() }
        let onPreferencesChange: @MainActor (CameraFlowPreferences) -> Void = receiver.store
        let onFinish: @MainActor ([CameraFlowPhoto]) -> Void = receiver.finish
        let onCancel: @MainActor () -> Void = receiver.cancel
        _ = CameraFlowView()
            .onCameraFlowPreferencesChange(perform: onPreferencesChange)
            .onCameraFlowFinish(perform: onFinish)
            .onCameraFlowCancel(perform: onCancel)
        let callbacks = ForwardedCallbacks(
            locationProvider: { receiver.location() },
            onPreferencesChange: { receiver.store($0) },
            onFinish: { receiver.finish(with: $0) },
            onCancel: { receiver.cancel() }
        )
        _ = CameraFlowView(configuration: CameraFlowConfiguration(), locationProvider: callbacks.locationProvider)
            .onCameraFlowPreferencesChange(perform: callbacks.onPreferencesChange)
            .onCameraFlowFinish(perform: callbacks.onFinish)
            .onCameraFlowCancel(perform: callbacks.onCancel)
    }

    @Test("The modifiers of the configuration chain on the view and on a view around it")
    @MainActor
    func configurationModifiers() {
        let receiver = Receiver()
        _ = VStack {
            CameraFlowView()
                .cameraFlowPhotoLimit(.single)
                .cameraFlowLanguage(.system)
                .onCameraFlowFinish { receiver.finish(with: $0) }
                .onCameraFlowCancel { receiver.cancel() }
        }
        .cameraFlowLibraryPickerEnabled(false)
        .cameraFlowPhotoLibrarySaving(CameraFlowPhotoLibrarySaving())
        .cameraFlowPhotoLocation(.appRequestsAccess)
        .cameraFlowPhotoDirection(.recorded)
        .cameraFlowOutput(CameraFlowOutput())
    }
}
#endif
