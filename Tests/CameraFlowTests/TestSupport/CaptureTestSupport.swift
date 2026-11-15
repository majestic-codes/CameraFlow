//
//  CaptureTestSupport.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import CoreLocation
import Foundation
import ImageIO
import Testing
@testable import CameraFlow

/// A model over a recording camera, with time that moves only when the test advances the clock. Live Photo is
/// offered, that is adjustable by the user, unless the test says otherwise (then it is fixed off) or the state
/// fixes it on. The second camera's circle is fixed off unless the test offers it: then the state says how. It has
/// no introduction unless the test gives one.
@MainActor
func makeCaptureModel(
    service: RecordingCameraService,
    haptics: RecordingCameraHaptics = RecordingCameraHaptics(),
    attitudeSensor: ManualAttitudeSensor = ManualAttitudeSensor(),
    initialState: CameraFlowInitialState = CameraFlowInitialState(),
    isLivePhotoOffered: Bool = true,
    isDualCameraOffered: Bool = false,
    output: CameraFlowOutput = CameraFlowOutput(),
    quality: PhotoQualityModel? = nil,
    preferences: CameraFlowPreferences = CameraFlowPreferences(),
    memory: PreferencesMemory? = nil,
    librarySaving: PhotoLibrarySavingModel? = nil,
    onboarding: OnboardingModel? = nil,
    clock: ManualClock = ManualClock(),
    files: CaptureFileStore = CaptureTestSupport.makeFileStore(),
    admission: (any CaptureAdmission)? = nil,
    heading: (any PhotoHeadingSource)? = nil,
    storage: any StorageSpace = FakeStorageSpace(),
    backgroundWork: any BackgroundWork = RecordingBackgroundWork(),
    onCapture: @escaping (CameraCapture) -> Void = { _ in },
    locationProvider: (() -> CLLocation?)? = nil,
    onPreferencesChange: ((CameraFlowPreferences) -> Void)? = nil
) -> PhotoCameraModel {
    var state = initialState
    let live = initialState.isLivePhotoEnabled
    if !isLivePhotoOffered {
        state.isLivePhotoEnabled = .fixed(false)
    } else if live == .fixed(false) {
        state.isLivePhotoEnabled = CameraFlowSetting(false)
    }
    if !isDualCameraOffered {
        state.isDualCameraEnabled = .fixed(false)
    }
    return PhotoCameraModel(
        service: service,
        haptics: haptics,
        attitudeSensor: attitudeSensor,
        initialState: state,
        quality: quality ?? PhotoQualityModel(output: output),
        choices: UserChoices(preferences: preferences, memory: memory, onChange: onPreferencesChange),
        librarySaving: librarySaving,
        onboarding: onboarding ?? OnboardingModel(setting: .off, service: service),
        clock: clock,
        files: files,
        location: locationProvider.map(FakeProvidedLocation.init),
        heading: heading,
        admission: admission,
        storage: storage,
        backgroundWork: backgroundWork,
        onCapture: onCapture
    )
}

extension PhotoCameraModel {
    /// A camera model of a flow with a fixed quality over an output, which opens with the initial state as it is,
    /// with the preferences and the memory given, and reports the user's choices to the closure. Without an
    /// introduction it has none. Its time moves only when the test advances the clock, and its files go under the
    /// directory of the test.
    convenience init(
        service: any CameraService,
        haptics: any CameraHaptics,
        attitudeSensor: any DeviceAttitudeSensor,
        initialState: CameraFlowInitialState = CameraFlowInitialState(),
        output: CameraFlowOutput = CameraFlowOutput(),
        preferences: CameraFlowPreferences = CameraFlowPreferences(),
        memory: PreferencesMemory? = nil,
        librarySaving: PhotoLibrarySavingModel? = nil,
        onboarding: OnboardingModel? = nil,
        clock: any Clock<Duration> = ManualClock(),
        files: CaptureFileStore = CaptureTestSupport.makeFileStore(),
        location: (any PhotoLocationSource)? = nil,
        admission: (any CaptureAdmission)? = nil,
        onCapture: @escaping (CameraCapture) -> Void,
        onPreferencesChange: ((CameraFlowPreferences) -> Void)? = nil
    ) {
        self.init(
            service: service,
            haptics: haptics,
            attitudeSensor: attitudeSensor,
            initialState: initialState,
            quality: PhotoQualityModel(output: output),
            choices: UserChoices(preferences: preferences, memory: memory, onChange: onPreferencesChange),
            librarySaving: librarySaving,
            onboarding: onboarding ?? OnboardingModel(setting: .off, service: service),
            clock: clock,
            files: files,
            location: location,
            heading: nil,
            admission: admission,
            storage: FakeStorageSpace(),
            backgroundWork: RecordingBackgroundWork(),
            onCapture: onCapture
        )
    }
}

extension PhotoSetModel {
    /// A set of a flow with a fixed quality over an output.
    convenience init(
        limit: CameraFlowPhotoLimit,
        fileStore: CaptureFileStore,
        output: CameraFlowOutput = CameraFlowOutput(),
        librarySaving: PhotoLibrarySavingModel? = nil,
        renderer: any MarkupRenderer,
        backgroundWork: any BackgroundWork = RecordingBackgroundWork(),
        onHandOver: @escaping ([CameraFlowPhoto]) -> Void
    ) {
        self.init(
            limit: limit,
            fileStore: fileStore,
            quality: PhotoQualityModel(output: output),
            librarySaving: librarySaving,
            renderer: renderer,
            backgroundWork: backgroundWork,
            onHandOver: onHandOver
        )
    }
}

extension CameraCapture {

    /// Width and height of the upright photo in pixels, as its file has it.
    func uprightPixelSize() throws -> CGSize {
        try PhotoFilePreview(url: fileURL).uprightSize
    }
}

extension PhotoSettingsModel {
    /// The user's choices as the app is told them: what the flow opened with, and every change of the user since.
    var preferences: CameraFlowPreferences {
        choices.reported
    }
}

enum CaptureTestSupport {
    /// A 12 MP camera with no Live Photo, no HEVC and exposure from -1 to 1.5.
    static let narrowCapabilities = PhotoCaptureCapabilities(
        flashModes: CameraFlowFlashMode.allCases,
        isLivePhotoSupported: false,
        exposureBiasRange: -1...1.5,
        formats: [.heif],
        encodesHEVC: false,
        resolution: PhotoCaptureResolution(width: 4032, height: 3024),
        lockableAdjustments: .focusAndExposure
    )

    /// A dual camera whose cameras deliver 8 MP only.
    static let dualWithSmallerSize = PhotoCaptureCapabilities(
        flashModes: CameraFlowFlashMode.allCases,
        isLivePhotoSupported: false,
        exposureBiasRange: -8...8,
        formats: [.heif],
        encodesHEVC: true,
        resolution: PhotoCaptureResolution(width: 3264, height: 2448),
        lockableAdjustments: .focusAndExposure
    )

    /// A camera whose photo output offers no flash, as the back camera of an iPad Air.
    static let withoutFlash = PhotoCaptureCapabilities(
        flashModes: [.off],
        isLivePhotoSupported: true,
        exposureBiasRange: -8...8,
        formats: [.heif],
        encodesHEVC: true,
        resolution: SimulatedCameraService.iPhoneBackPhotoCapabilities.resolution,
        lockableAdjustments: .focusAndExposure
    )

    /// A dual camera whose back camera has no flash beside the front one.
    static let dualWithoutFlash = PhotoCaptureCapabilities(
        flashModes: [.off],
        isLivePhotoSupported: false,
        exposureBiasRange: -8...8,
        formats: [.heif],
        encodesHEVC: true,
        resolution: SimulatedCameraService.iPhoneDualPhotoCapabilities.resolution,
        lockableAdjustments: .focusAndExposure
    )

    /// A store in a directory of its own under the test temporary directory.
    static func makeFileStore() -> CaptureFileStore {
        CaptureFileStore(parent: TestDirectory.current)
    }

    static func isSquare(_ capture: CameraCapture) throws -> Bool {
        let size = try capture.uprightPixelSize()
        return size.width == size.height
    }

    /// Deletes the files of a capture the test received, as a receiver must.
    static func discardFiles(of capture: CameraCapture) throws {
        for url in capture.fileURLs {
            try FileManager.default.removeItem(at: url)
        }
    }
}
