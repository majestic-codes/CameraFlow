//
//  PhotoSettingsModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Observation

/// The settings of the next photo, what the running camera and the app's constraints offer for each, and the
/// request they make.
///
/// A setting the app fixed has no control and keeps its value. An adjustable one opens with the app's stored
/// preference, or else with what the user chose last time, where the flow remembers it, or else with the app's
/// value. Every change the user makes to it is remembered and reported through `onPreferencesChange`.
///
/// The running camera may offer less than the user chose, as a camera without a flash or one of the dual camera does.
/// A chosen setting it does not offer stays chosen and comes back with a camera that offers it. Meanwhile the photo is
/// taken with what is offered, and the indicators and the panel show that.
///
/// `PhotoCameraModel` hands over what the running camera offers whenever a camera has started, and hears every change
/// the user makes through `onUserChange`.
@MainActor
@Observable
final class PhotoSettingsModel {
    private(set) var flashMode: CameraFlowFlashMode
    private(set) var isLivePhotoEnabled: Bool
    private(set) var aspectRatio: CameraFlowAspectRatio
    private(set) var timer: CameraFlowTimer
    /// Exposure bias in stops, kept inside `exposureBiasRange`.
    private(set) var exposureBias: Double
    private(set) var photoFormat: CameraFlowPhotoFormat
    /// Whether the screen has Live Photo at all: adjustable by the user, or fixed on by the app.
    let isLivePhotoOffered: Bool
    /// Saving to the photo library, nil in a flow that never saves.
    let librarySaving: PhotoLibrarySavingModel?
    /// The quality of the photos, which narrows the app's output and so what the panel can offer.
    let quality: PhotoQualityModel
    /// Whether the circle opens on: what the user chose last time where the flow remembers it and the user may
    /// switch it, the app's value otherwise. A device without the circle opens without it all the same.
    let opensWithDualCamera: Bool
    /// Whether the circle's toggle is a setting here: `DualCameraModel.isToggleOffered` as `PhotoCameraModel` hands
    /// it over.
    private(set) var isDualCameraOffered: Bool
    /// What the running camera can do for photos, nil until it has started.
    private(set) var photoCapabilities: PhotoCaptureCapabilities?
    /// Whether the two cameras run together, for the value of the circle's tile and what the pair offers.
    private(set) var isDualCameraOn = false
    /// The flash of the running camera as it reports it, which changes through its own methods.
    var flash = CameraFlash()

    @ObservationIgnored private let state: CameraFlowInitialState
    /// What the user chose, as the flow remembers it and tells the app.
    @ObservationIgnored private(set) var choices: UserChoices
    /// Called when the user changes a setting, before the change takes effect.
    @ObservationIgnored var onUserChange: (() -> Void)?
    /// The running camera, which the extensions of the settings hand what it takes.
    @ObservationIgnored let service: any CameraService
    @ObservationIgnored private let haptics: any CameraHaptics

    nonisolated static let exposureBiasRange = -2.0...2.0

    /// The quality carries the output of the app, and the choices what the flow opens with.
    init(
        initialState: CameraFlowInitialState,
        quality: PhotoQualityModel,
        choices: UserChoices,
        librarySaving: PhotoLibrarySavingModel?,
        isDualCameraOffered: Bool,
        service: any CameraService,
        haptics: any CameraHaptics
    ) {
        state = initialState
        self.quality = quality
        let stored = choices.reported
        self.choices = choices
        self.librarySaving = librarySaving
        self.isDualCameraOffered = isDualCameraOffered
        self.service = service
        self.haptics = haptics
        let live = initialState.isLivePhotoEnabled
        isLivePhotoOffered = live.canBeOn
        flashMode = initialState.flashMode.resolved(with: stored.flashMode)
        isLivePhotoEnabled = live.resolved(with: stored.isLivePhotoEnabled)
        aspectRatio = initialState.aspectRatio.resolved(with: stored.aspectRatio)
        timer = initialState.timer.resolved(with: stored.timer)
        exposureBias = Self.clamped(initialState.exposureBias.value, to: Self.exposureBiasRange)
        photoFormat = initialState.photoFormat.resolved(with: stored.photoFormat)
        opensWithDualCamera = initialState.isDualCameraEnabled.resolved(with: stored.isDualCameraEnabled)
    }

    // MARK: - Changing a setting

    /// Moves to the next flash mode, on a camera that offers a flash, and has the camera monitor its scene for it.
    func cycleFlash() {
        guard isFlashSelectable else { return }
        onUserChange?()
        flashMode = switch flashMode {
        case .auto: .alwaysOn
        case .alwaysOn: .off
        case .off: .auto
        }
        recordCameraChoices()
        monitorFlashScene()
    }

    func toggleLivePhoto() {
        onUserChange?()
        isLivePhotoEnabled.toggle()
        recordCameraChoices()
    }

    /// Sets the flash mode from its sub-panel, as `cycleFlash()` moves it.
    func select(flashMode: CameraFlowFlashMode) {
        guard isFlashSelectable, flashMode != self.flashMode else { return }
        select(\.flashMode, flashMode)
        monitorFlashScene()
    }

    func select(isLivePhotoEnabled: Bool) {
        select(\.isLivePhotoEnabled, isLivePhotoEnabled)
    }

    func select(aspectRatio: CameraFlowAspectRatio) {
        select(\.aspectRatio, aspectRatio)
    }

    func select(timer: CameraFlowTimer) {
        select(\.timer, timer)
    }

    /// Sets the format from its sub-panel. The camera monitors its scene again when the format of the next photo moves.
    func select(photoFormat: CameraFlowPhotoFormat) {
        followingCaptureFormat { select(\.photoFormat, photoFormat) }
    }

    /// A finger came down on an option of a sub-panel: the haptic its release plays when it changes the setting is
    /// readied.
    func optionTouched() {
        haptics.prepare(for: .optionSelected)
    }

    /// Sets the quality from its row of the Format sub-panel. Choosing a different one plays the selection haptic
    /// and is reported to the app, and the camera monitors its scene again when the format of the next photo moves.
    func select(photoQuality: CameraFlowQuality) {
        let isSelected = followingCaptureFormat { quality.select(photoQuality) }
        guard isSelected else { return }
        onUserChange?()
        haptics.play(.optionSelected)
        recordPhotoQualityChoice()
    }

    /// Clamps to `availableExposureBiasRange` and sends the bias to the running camera.
    func setExposureBias(_ bias: Double) {
        onUserChange?()
        applyExposureBias(bias)
    }

    /// Moves the bias by a step, as VoiceOver adjusts it. A bias the app fixed stays as it is.
    func stepExposureBias(by step: Double) {
        guard isExposureAdjustable else { return }
        setExposureBias(exposureBias + step)
    }

    /// Takes a bias the Camera Control already applied to the camera. A bias the screen does not take, outside its
    /// range or of an exposure the app fixed, is replaced by the one in effect, which goes back to the camera.
    func exposureBiasChanged(to bias: Double) {
        let kept = isExposureAdjustable ? Self.clamped(bias, to: availableExposureBiasRange) : exposureBias
        exposureBias = kept
        if kept != bias, photoCapabilities != nil {
            service.setExposureBias(kept)
        }
    }

    /// Takes what a camera that has just started offers, and gives it the flash mode and the bias it accepts.
    func cameraStarted(photoCapabilities: PhotoCaptureCapabilities?, isDualCameraOn: Bool) {
        self.photoCapabilities = photoCapabilities
        self.isDualCameraOn = isDualCameraOn
        applyExposureBias(exposureBias)
        monitorFlashScene()
    }

    /// The circle failed to start for good, so its toggle is no longer a setting here.
    func dualCameraBecameUnavailable() {
        isDualCameraOffered = false
    }

    private func applyExposureBias(_ bias: Double) {
        exposureBias = Self.clamped(bias, to: availableExposureBiasRange)
        if photoCapabilities != nil {
            service.setExposureBias(exposureBias)
        }
    }

    /// Sets a setting from its sub-panel. Choosing a different value plays the selection haptic.
    private func select<Value: Equatable>(
        _ setting: ReferenceWritableKeyPath<PhotoSettingsModel, Value>,
        _ value: Value
    ) {
        guard self[keyPath: setting] != value else { return }
        onUserChange?()
        self[keyPath: setting] = value
        haptics.play(.optionSelected)
        recordCameraChoices()
    }

    // MARK: - Saving to the photo library

    /// Whether the next photo is saved to the photo library.
    var isLibrarySavingOn: Bool {
        librarySaving?.isOn ?? false
    }

    /// The Save indicator: switches saving, which asks for library access when it goes on.
    func toggleLibrarySaving() async {
        await select(isLibrarySavingEnabled: !isLibrarySavingOn)
    }

    /// Sets saving from its sub-panel. Choosing a different value plays the selection haptic. A switch the library
    /// refused is not recorded, and the saving keeps why.
    func select(isLibrarySavingEnabled: Bool) async {
        guard let librarySaving, librarySaving.isUserAdjustable, librarySaving.isOn != isLibrarySavingEnabled else {
            return
        }
        onUserChange?()
        haptics.play(.optionSelected)
        guard await librarySaving.setOn(isLibrarySavingEnabled) == nil else { return }
        recordLibrarySavingChoice()
    }

    // MARK: - What the app lets the user change

    /// The settings with a tile in the control panel, in the stock order: the ones the app made adjustable.
    var offeredSettings: [CameraSetting] {
        CameraSetting.allCases.filter(isAdjustable)
    }

    /// Whether the exposure bias may be changed, on its tile and with the drag beside the focus reticle.
    var isExposureAdjustable: Bool {
        state.exposureBias.isUserAdjustable
    }

    /// Whether the app lets the user change a setting: it then has a tile, and its control or indicator in the
    /// top bar.
    func isAdjustable(_ setting: CameraSetting) -> Bool {
        switch setting {
        case .flash: state.flashMode.isUserAdjustable
        case .live: state.isLivePhotoEnabled.isUserAdjustable
        case .aspect: state.aspectRatio.isUserAdjustable
        case .timer: state.timer.isUserAdjustable
        case .exposure: state.exposureBias.isUserAdjustable
        case .format: state.photoFormat.isUserAdjustable || quality.isUserAdjustable
        case .dualCamera: isDualCameraOffered
        case .librarySave: librarySaving?.isUserAdjustable ?? false
        }
    }

    // MARK: - The request

    /// The settings as a request for one photo, checked against the capabilities of the running camera.
    func makeRequest(
        for photoCapabilities: PhotoCaptureCapabilities
    ) throws(CameraServiceError) -> PhotoCaptureRequest {
        guard let resolution = effectivePhotoFrame else {
            throw .unsupported(.resolution)
        }
        return try PhotoCaptureRequest(
            flashMode: photoFlashMode,
            isLivePhotoEnabled: isLivePhotoInEffect,
            format: effectivePhotoFormat,
            resolution: resolution,
            capabilities: photoCapabilities
        )
    }

    nonisolated private static func clamped(_ bias: Double, to range: ClosedRange<Double>) -> Double {
        min(max(bias, range.lowerBound), range.upperBound)
    }
}

// MARK: - What the screen, the running camera and the output offer

extension PhotoSettingsModel {
    /// Whether Live Photo can be used now: the screen has it and the running camera supports it.
    var isLivePhotoAvailable: Bool {
        isLivePhotoOffered && (photoCapabilities?.isLivePhotoSupported ?? false)
    }

    /// Whether Live Photo can be switched on now: the camera supports it, RAW is not in effect, since the API
    /// forbids Live Photo with Apple ProRAW, and the photo is 4:3, since the movie is never cropped.
    var isLivePhotoSelectable: Bool {
        isLivePhotoAvailable && effectivePhotoFormat != .raw && aspectRatio == .fourByThree
    }

    /// Whether the next photo is taken as a Live Photo. Live Photo stays chosen where it cannot be switched on, and
    /// comes back with HEIF, with 4:3 and with a camera that has it.
    var isLivePhotoInEffect: Bool {
        isLivePhotoEnabled && isLivePhotoSelectable
    }

    /// Whether the running camera writes its HEIF photos as HEIC. False where they fall back to JPEG, and until the
    /// camera has started.
    var encodesHEVC: Bool {
        photoCapabilities?.encodesHEVC ?? false
    }

    /// Formats the running camera offers that an output can take. RAW needs an output that leaves the file as it
    /// is, and a size no smaller than the camera's: a DNG cannot be scaled, re-encoded or stripped.
    private func photoFormats(within output: CameraFlowOutput) -> [CameraFlowPhotoFormat] {
        let formats = photoCapabilities?.formats ?? []
        let takesRAW = output.leavesFilesAsTheyAre && deliversPhotos(within: output)
        return formats.filter { $0 != .raw || takesRAW }
    }

    /// Formats the running camera offers that the output can take. Empty until the camera has started.
    var availablePhotoFormats: [CameraFlowPhotoFormat] {
        photoFormats(within: output)
    }

    /// Formats the Format panel shows, in the stock order: the ones the widest output the user may pick takes, so
    /// the row keeps its options whatever the quality is. None while the app fixed the format.
    var offeredPhotoFormats: [CameraFlowPhotoFormat] {
        guard state.photoFormat.isUserAdjustable else { return [] }
        let available = photoFormats(within: quality.widestOutput)
        return CameraFlowPhotoFormat.allCases.filter(available.contains)
    }

    /// The format a capture uses: `photoFormat` when the camera and the output take it, HEIF otherwise.
    var effectivePhotoFormat: CameraFlowPhotoFormat {
        availablePhotoFormats.contains(photoFormat) ? photoFormat : .heif
    }

    /// `exposureBiasRange` narrowed to what the running camera accepts.
    var availableExposureBiasRange: ClosedRange<Double> {
        guard let deviceRange = photoCapabilities?.exposureBiasRange else {
            return Self.exposureBiasRange
        }
        return deviceRange.clamped(to: Self.exposureBiasRange)
    }
}

// MARK: - What the user chose, remembered and reported

extension PhotoSettingsModel {

    /// Records the camera settings the user just moved: the adjustable ones whose value is no longer the one the
    /// flow opened with or recorded last. A setting the app fixed is never recorded.
    private func recordCameraChoices() {
        let known = choices.reported
        var changes = CameraFlowPreferences()
        changes.flashMode = change(flashMode, of: state.flashMode, known: known.flashMode)
        let livePhoto = state.isLivePhotoEnabled
        changes.isLivePhotoEnabled = change(isLivePhotoEnabled, of: livePhoto, known: known.isLivePhotoEnabled)
        changes.aspectRatio = change(aspectRatio, of: state.aspectRatio, known: known.aspectRatio)
        changes.timer = change(timer, of: state.timer, known: known.timer)
        changes.photoFormat = change(photoFormat, of: state.photoFormat, known: known.photoFormat)
        choices.record(changes)
    }

    /// Records the quality the user just picked on its row.
    private func recordPhotoQualityChoice() {
        var changes = CameraFlowPreferences()
        changes.photoQuality = photoQuality
        choices.record(changes)
    }

    /// Records saving to the photo library as the user just switched it.
    private func recordLibrarySavingChoice() {
        var changes = CameraFlowPreferences()
        changes.isPhotoLibrarySavingEnabled = isLibrarySavingOn
        choices.record(changes)
    }

    /// Records the circle as the user just switched it, where the user may switch it. Nothing else records the
    /// circle, so a flow without it leaves the choice as it is.
    func recordDualCameraChoice(isOn: Bool) {
        guard state.isDualCameraEnabled.isUserAdjustable else { return }
        var changes = CameraFlowPreferences()
        changes.isDualCameraEnabled = isOn
        choices.record(changes)
    }

    /// The value of a setting when the user may change it and moved it away from the known choice, nil otherwise.
    private func change<Value: Equatable>(
        _ value: Value,
        of setting: CameraFlowSetting<Value>,
        known: Value?
    ) -> Value? {
        guard setting.isUserAdjustable, value != setting.resolved(with: known) else { return nil }
        return value
    }
}
