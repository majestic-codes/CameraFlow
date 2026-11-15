//
//  CameraScreenFactory.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import CoreLocation

/// Builds the models of a flow over the camera of this device. Nothing else names a concrete camera.
@MainActor
enum CameraScreenFactory {

    /// A flow with an empty set and a camera that adds to it. The set shares the camera's directory, and its
    /// photos reach `onFinish` as the app receives them. Drawings are made, shown and written with the markup
    /// engine of the system, and photos are saved to the system photo library through Photos. The system keeps the
    /// app running in the background for a photo, a save and the hand-over under way.
    ///
    /// - Precondition: the app's Info.plist has the usage description of every system resource the flow asks for
    ///   (`UsageDescription`).
    static func makeFlow(
        configuration: CameraFlowConfiguration,
        locationProvider: (() -> CLLocation?)?,
        onPreferencesChange: ((CameraFlowPreferences) -> Void)?,
        onFinish: @escaping ([CameraFlowPhoto]) -> Void,
        onCancel: @escaping () -> Void
    ) -> EmbeddedCameraFlowModel {
        let files = CaptureFileStore()
        removeStaleDirectories(beside: files)
        let haptics = DeviceCameraHaptics()
        let renderer = SystemMarkupRenderer()
        let backgroundWork = ExpiringActivityWork()
        let source = CameraSource.resolve(usesSimulatedCamera: configuration.camera.usesSimulatedCamera)
        let libraryWriter = makeLibraryWriter(for: source, configuration: configuration)
        let memory = makeMemory(for: configuration.settingsMemory)
        let choices = UserChoices(preferences: configuration.preferences, memory: memory, onChange: onPreferencesChange)
        let librarySaving = makeLibrarySaving(configuration.photoLibrarySaving, opening: choices, writer: libraryWriter)
        let quality = PhotoQualityModel(
            setting: configuration.photoQuality,
            preference: choices.reported.photoQuality,
            output: configuration.output,
            levels: configuration.photoQualityLevels,
            libraryOutput: configuration.libraryOutput
        )
        let photoSet = PhotoSetModel(
            limit: configuration.effectivePhotoLimit,
            fileStore: files,
            quality: quality,
            librarySaving: librarySaving,
            renderer: renderer,
            backgroundWork: backgroundWork,
            onHandOver: onFinish
        )
        let shared = SharedModels(
            source: source,
            files: files,
            haptics: haptics,
            backgroundWork: backgroundWork,
            choices: choices,
            librarySaving: librarySaving,
            quality: quality,
            photoSet: photoSet
        )
        let location = makeLocation(configuration: configuration, source: source, locationProvider: locationProvider)
        let camera = makeModel(configuration: configuration, shared: shared, location: location)
        return CameraFlowModel(
            camera: camera,
            photoSet: photoSet,
            renderer: renderer,
            openCanvas: { photo, drawing in try MarkupCanvasFactory.makeCanvas(photo: photo, drawing: drawing) },
            isLibraryPickerEnabled: configuration.isLibraryPickerEnabled,
            completion: configuration.completion,
            haptics: haptics,
            onExit: onCancel
        )
    }

    /// Removes what earlier runs of the program left behind, off the main actor.
    private static func removeStaleDirectories(beside files: CaptureFileStore) {
        Task.detached(priority: .utility) {
            files.removeStaleDirectories()
        }
    }

    /// Saving to the photo library, nil in a flow that never saves. It opens on the preference the app stored or
    /// the flow remembers where the user may switch it.
    private static func makeLibrarySaving(
        _ saving: CameraFlowPhotoLibrarySaving,
        opening: UserChoices,
        writer: any PhotoLibraryWriter
    ) -> PhotoLibrarySavingModel? {
        guard saving.isPossible else { return nil }
        return PhotoLibrarySavingModel(
            saving: saving,
            isOn: opening.opensLibrarySaving(saving),
            writer: writer
        )
    }

    /// The system photo library, or a simulated one where the simulated camera opens with simulated access. A flow
    /// that may save to the system library needs the usage description of its destination.
    private static func makeLibraryWriter(
        for source: CameraSource,
        configuration: CameraFlowConfiguration
    ) -> any PhotoLibraryWriter {
        let saving = configuration.photoLibrarySaving
        switch (source, configuration.simulatedAccess.photoLibrary) {
        case (.device, _), (.simulated, .system):
            if saving.isPossible {
                UsageDescription.photoLibrary(for: saving.destination).require(in: Self.infoValue)
            }
            return PhotosLibraryWriter()
        case let (.simulated, .simulated(isAuthorizationDetermined)):
            return SimulatedPhotoLibrary(isAuthorizationDetermined: isAuthorizationDetermined)
        }
    }

    /// Where the photos take their location and direction from, and the access the flow asks for, with the
    /// location and the compass of this device.
    private static func makeLocation(
        configuration: CameraFlowConfiguration,
        source: CameraSource,
        locationProvider: (() -> CLLocation?)?
    ) -> PhotoLocationPlan {
        PhotoLocationPlan(
            configuration: configuration,
            locationProvider: locationProvider,
            makeProvidedLocation: { ProvidedPhotoLocation($0) },
            makeSystemLocation: {
                makeSystemLocation(
                    for: source,
                    access: configuration.simulatedAccess,
                    asksForAccess: configuration.asksForLocation
                )
            },
            makeCompass: { CoreHeadingSource(followsLocation: $0) }
        )
    }

    /// The location of Core Location, or a simulated one where the simulated camera opens with simulated access. A
    /// flow that asks Core Location for access needs its usage description.
    private static func makeSystemLocation(
        for source: CameraSource,
        access: SimulatedAccess,
        asksForAccess: Bool
    ) -> any LocationAuthorizer & PhotoLocationSource {
        switch (source, access.location) {
        case (.device, _), (.simulated, .system):
            if asksForAccess {
                UsageDescription.locationWhenInUse.require(in: Self.infoValue)
            }
            return CoreLocationSource()
        case let (.simulated, .simulated(authorization, answerOnRequest)):
            return SimulatedLocation(authorization: authorization, answerOnRequest: answerOnRequest)
        }
    }

    /// A value of the app's Info.plist.
    private static func infoValue(_ key: String) -> Any? {
        Bundle.main.object(forInfoDictionaryKey: key)
    }

    /// What the camera shares with the rest of the flow.
    private struct SharedModels {
        /// The camera the flow runs on, which its attitude sensor goes with.
        let source: CameraSource
        let files: CaptureFileStore
        let haptics: DeviceCameraHaptics
        /// Keeps the app running for the work the user started.
        let backgroundWork: ExpiringActivityWork
        /// What the user chose in earlier flows, which the camera opens with and adds to.
        let choices: UserChoices
        let librarySaving: PhotoLibrarySavingModel?
        /// The quality the camera offers and the set applies to its picks.
        let quality: PhotoQualityModel
        let photoSet: PhotoSetModel
    }

    /// A model over the camera `CameraSource` picks: the device's, or the simulated one in the iOS Simulator and
    /// where the state asks for it.
    private static func makeModel(
        configuration: CameraFlowConfiguration,
        shared: SharedModels,
        location: PhotoLocationPlan
    ) -> PhotoCameraModel {
        let service = makeService(for: configuration, source: shared.source)
        let onboarding = OnboardingModel(
            setting: configuration.onboarding,
            service: service,
            location: location.authorizer,
            librarySaving: shared.librarySaving
        )
        return PhotoCameraModel(
            service: service,
            haptics: shared.haptics,
            attitudeSensor: makeAttitudeSensor(for: shared.source, initialState: configuration.camera),
            initialState: configuration.camera,
            quality: shared.quality,
            choices: shared.choices,
            librarySaving: shared.librarySaving,
            onboarding: onboarding,
            files: shared.files,
            location: location.source,
            heading: location.heading,
            admission: shared.photoSet,
            storage: VolumeStorageSpace(directory: FileManager.default.temporaryDirectory),
            backgroundWork: shared.backgroundWork,
            onCapture: shared.photoSet.add
        )
    }

    /// The memory of the user's choices in `UserDefaults`, nil for a flow that forgets them.
    private static func makeMemory(for settingsMemory: CameraFlowSettingsMemory) -> PreferencesMemory? {
        guard case let .userDefaults(_, keyPrefix) = settingsMemory, let defaults = settingsMemory.defaults else {
            return nil
        }
        return PreferencesMemory(store: UserDefaultsPreferenceStore(defaults: defaults), keyPrefix: keyPrefix)
    }

    private static func makeService(
        for configuration: CameraFlowConfiguration,
        source: CameraSource
    ) -> any CameraService {
        let features = PhotoCaptureFeatures(camera: configuration.camera, output: configuration.output)
        switch source {
        case .device:
            UsageDescription.camera.require(in: Self.infoValue)
            let controlsSetup = CaptureControlsSetup(
                isExposureAdjustable: configuration.camera.exposureBias.isUserAdjustable,
                localization: FlowLocalization(configuration.language)
            )
            return CaptureCameraService(features: features, controlsSetup: controlsSetup)
        case .simulated:
            let access = configuration.simulatedAccess
            return SimulatedCameraService(
                scene: configuration.camera.simulatedScene,
                features: features,
                isAuthorizationDetermined: access.grantsCameraBefore,
                authorizationOnRequest: access.cameraAnswer,
                startFailureCount: configuration.camera.simulatedStartFailureCount
            )
        }
    }

    /// The device camera goes with the phone's own attitude, and the simulated one with the fixed orientation of
    /// the state.
    private static func makeAttitudeSensor(
        for source: CameraSource,
        initialState: CameraFlowInitialState
    ) -> any DeviceAttitudeSensor {
        switch source {
        case .device: DeviceMotionAttitudeSensor()
        case .simulated: SimulatedAttitudeSensor(orientation: initialState.simulatedOrientation)
        }
    }
}
#endif
