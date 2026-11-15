//
//  CameraFlowModifiers.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 15.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

extension View {

    /// Sets ``CameraFlowConfiguration/language`` of every ``CameraFlowView`` inside this view: the language of the
    /// flow's own texts and of the numbers in them.
    ///
    /// As with the configuration, the texts on the screen follow the latest value, while the lens picker of the Camera
    /// Control keeps the language the flow started with. See <doc:SwiftUIModifiers> for how the modifiers combine with
    /// the configuration.
    /// - Parameter language: The language, as ``CameraFlowLanguage`` describes it.
    nonisolated public func cameraFlowLanguage(_ language: CameraFlowLanguage) -> some View {
        changingCameraFlowConfiguration(.language(language))
    }

    /// Sets ``CameraFlowConfiguration/photoLimit`` of every ``CameraFlowView`` inside this view: the most photos one
    /// set holds, camera and library together.
    ///
    /// Read once, when the flow starts. A ``CameraFlowPhotoLimit/maximum(_:)`` below 1 stops the program then. See
    /// <doc:SwiftUIModifiers> for how the modifiers combine with the configuration.
    /// - Parameter limit: The limit of the set.
    nonisolated public func cameraFlowPhotoLimit(_ limit: CameraFlowPhotoLimit) -> some View {
        changingCameraFlowConfiguration(.photoLimit(limit))
    }

    /// Sets ``CameraFlowConfiguration/isLibraryPickerEnabled`` of every ``CameraFlowView`` inside this view: whether
    /// the flow offers the round library button and the "+" tile.
    ///
    /// Read once, when the flow starts. See <doc:SwiftUIModifiers> for how the modifiers combine with the
    /// configuration.
    /// - Parameter isEnabled: Whether the user may add photos from the photo library.
    nonisolated public func cameraFlowLibraryPickerEnabled(_ isEnabled: Bool) -> some View {
        changingCameraFlowConfiguration(.libraryPicker(isEnabled: isEnabled))
    }

    /// Sets ``CameraFlowConfiguration/photoLibrarySaving`` of every ``CameraFlowView`` inside this view as a whole:
    /// whether the photos the camera takes are also saved to the system photo library, whether the user decides, where
    /// they go and when.
    ///
    /// ```swift
    /// var saving = CameraFlowPhotoLibrarySaving()
    /// saving.isEnabled = CameraFlowSetting(true)
    /// saving.destination = .album(named: "Field photos")
    ///
    /// CameraFlowView()
    ///     .cameraFlowPhotoLibrarySaving(saving)
    /// ```
    ///
    /// Read once, when the flow starts, with the checks of the configuration: a blank album name stops the program
    /// then. The app's Info.plist needs the usage descriptions ``CameraFlowPhotoLibrarySaving`` names. See
    /// <doc:SwiftUIModifiers> for how the modifiers combine with the configuration.
    /// - Parameter saving: The saving to the photo library, which replaces the configuration's.
    nonisolated public func cameraFlowPhotoLibrarySaving(_ saving: CameraFlowPhotoLibrarySaving) -> some View {
        changingCameraFlowConfiguration(.photoLibrarySaving(saving))
    }

    /// Sets ``CameraFlowConfiguration/photoLocation`` of every ``CameraFlowView`` inside this view: whether the photos
    /// the camera takes record where they were taken, and whether the flow asks for location access.
    ///
    /// Read once, when the flow starts. A view created with a `locationProvider` under
    /// ``CameraFlowPhotoLocation/off`` stops the program then. See <doc:SwiftUIModifiers> for how the modifiers combine
    /// with the configuration.
    /// - Parameter location: Whether and how the photos record their location.
    nonisolated public func cameraFlowPhotoLocation(_ location: CameraFlowPhotoLocation) -> some View {
        changingCameraFlowConfiguration(.photoLocation(location))
    }

    /// Sets ``CameraFlowConfiguration/photoDirection`` of every ``CameraFlowView`` inside this view: whether the
    /// photos the camera takes record the direction the camera pointed in.
    ///
    /// Read once, when the flow starts. See <doc:SwiftUIModifiers> for how the modifiers combine with the
    /// configuration.
    /// - Parameter direction: Whether the photos record the direction of the camera.
    nonisolated public func cameraFlowPhotoDirection(_ direction: CameraFlowPhotoDirection) -> some View {
        changingCameraFlowConfiguration(.photoDirection(direction))
    }

    /// Sets ``CameraFlowConfiguration/output`` of every ``CameraFlowView`` inside this view as a whole: the size, the
    /// file format and the metadata of the photos the app receives, and of the photos picked from the library while
    /// ``CameraFlowConfiguration/libraryOutput`` is ``CameraFlowLibraryOutput/sameAsCamera``.
    ///
    /// ```swift
    /// var output = CameraFlowOutput()
    /// output.size = .standard
    /// output.format = .jpeg(quality: 0.8)
    ///
    /// CameraFlowView()
    ///     .cameraFlowOutput(output)
    /// ```
    ///
    /// Read once, when the flow starts, with the checks of the configuration: a size below 1 pixel, a compression
    /// quality outside 0...1, and an output that encodes the photos again or strips their metadata under a RAW
    /// ``CameraFlowInitialState/photoFormat`` stop the program then. See <doc:SwiftUIModifiers> for how the modifiers
    /// combine with the configuration.
    /// - Parameter output: The output, which replaces the configuration's.
    nonisolated public func cameraFlowOutput(_ output: CameraFlowOutput) -> some View {
        changingCameraFlowConfiguration(.output(output))
    }

    /// Receives the photos of the set of every ``CameraFlowView`` inside this view, in their order, once, when the
    /// user accepts the set. The receiver owns their files: see ``CameraFlowPhoto``.
    ///
    /// A set has one receiver: the action of the modifier nearest to the view. As with SwiftUI's own actions, the flow
    /// calls the action of the latest update of the view, not the one it started with. The flow needs this modifier,
    /// on the view or on a view around it, for as long as it runs: a flow that starts without it stops the program.
    /// Dismiss the view from the action. Called on the main actor. See <doc:SwiftUIModifiers>.
    /// - Parameter action: Receives the photos of the accepted set.
    nonisolated public func onCameraFlowFinish(perform action: @escaping ([CameraFlowPhoto]) -> Void) -> some View {
        transformEnvironment(\.flowModifierCallbacks) { callbacks in
            callbacks.onFinish = action
        }
    }

    /// Tells every ``CameraFlowView`` inside this view what to do when the user leaves its flow without a set.
    ///
    /// The action of the modifier nearest to the view runs. As with SwiftUI's own actions, the flow calls the action of
    /// the latest update of the view, not the one it started with. The flow needs this modifier, on the view or on a
    /// view around it, for as long as it runs: a flow that starts without it stops the program. Dismiss the view from
    /// the action. Called on the main actor. See <doc:SwiftUIModifiers>.
    /// - Parameter action: Called when the user leaves the flow without a set.
    nonisolated public func onCameraFlowCancel(perform action: @escaping () -> Void) -> some View {
        transformEnvironment(\.flowModifierCallbacks) { callbacks in
            callbacks.onCancel = action
        }
    }

    /// Receives the user's choices (``CameraFlowPreferences``) of every ``CameraFlowView`` inside this view, after
    /// every change the user makes to an adjustable setting, and never for a change the flow makes on its own. The
    /// last value is the one to store.
    ///
    /// The action of the modifier nearest to the view runs. As with SwiftUI's own actions, the flow calls the action of
    /// the latest update of the view, not the one it started with. The flow needs no receiver of the preferences.
    /// Called on the main actor. See <doc:SwiftUIModifiers>.
    /// - Parameter action: Receives the user's choices.
    nonisolated public func onCameraFlowPreferencesChange(
        perform action: @escaping (CameraFlowPreferences) -> Void
    ) -> some View {
        transformEnvironment(\.flowModifierCallbacks) { callbacks in
            callbacks.onPreferencesChange = action
        }
    }

    /// Adds a change of the configuration after the ones of the modifiers further out.
    nonisolated private func changingCameraFlowConfiguration(_ change: FlowConfigurationChanges.Change) -> some View {
        transformEnvironment(\.flowConfigurationChanges) { changes in
            changes.append(change)
        }
    }

    /// Sets the modifiers of the flow as the base of the ones inside this view, as the cover carries them from the
    /// view that presents it.
    func flowModifierEnvironment(_ modifiers: FlowModifierEnvironment) -> some View {
        environment(\.flowConfigurationChanges, modifiers.changes)
            .environment(\.flowModifierCallbacks, modifiers.callbacks)
    }
}

/// The modifiers of the flow in one environment: the properties of the configuration they set and their closures.
struct FlowModifierEnvironment {
    var changes = FlowConfigurationChanges()
    var callbacks = FlowCallbacks()
}

private struct FlowConfigurationChangesKey: EnvironmentKey {
    static let defaultValue = FlowConfigurationChanges()
}

private struct FlowModifierCallbacksKey: EnvironmentKey {
    /// No closure. Computed, since a closure is not `Sendable`.
    static var defaultValue: FlowCallbacks {
        FlowCallbacks()
    }
}

extension EnvironmentValues {
    /// The properties of the configuration that the modifiers of the flow set, which `CameraFlowView` applies over its
    /// own configuration when its flow starts.
    var flowConfigurationChanges: FlowConfigurationChanges {
        get { self[FlowConfigurationChangesKey.self] }
        set { self[FlowConfigurationChangesKey.self] = newValue }
    }

    /// The closures the modifiers of the flow set, which replace the ones of `CameraFlowView` at every update.
    var flowModifierCallbacks: FlowCallbacks {
        get { self[FlowModifierCallbacksKey.self] }
        set { self[FlowModifierCallbacksKey.self] = newValue }
    }

    /// Every modifier of the flow in this environment.
    var flowModifierEnvironment: FlowModifierEnvironment {
        FlowModifierEnvironment(changes: flowConfigurationChanges, callbacks: flowModifierCallbacks)
    }
}
#endif
