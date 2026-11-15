//
//  PhotoSettingsModel+Flash.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

// MARK: - The flash of the running camera

/// One rule for every camera, alone or in the pair: the chosen flash mode where the running camera offers it, and
/// off where it does not, while the chosen mode stays and comes back with a camera that has it.
extension PhotoSettingsModel {
    /// Flash modes the running camera offers. Empty until it has started.
    var availableFlashModes: [CameraFlowFlashMode] {
        photoCapabilities?.flashModes ?? []
    }

    /// Whether the running camera offers a flash, so the Flash indicator, its tile and its sub-panel take a choice:
    /// every camera but one that offers off alone, and any before a camera has started.
    var isFlashSelectable: Bool {
        availableFlashModes.isEmpty || availableFlashModes.contains { $0 != .off }
    }

    /// The flash mode the running camera takes: the chosen one, or off where the camera does not offer it. It is the
    /// chosen one until a camera has started.
    var effectiveFlashMode: CameraFlowFlashMode {
        let flashModes = availableFlashModes
        guard !flashModes.isEmpty, !flashModes.contains(flashMode) else {
            return flashMode
        }
        return .off
    }

    /// The flash mode of the next photo: the one the running camera takes, or off while its flash cannot fire.
    var photoFlashMode: CameraFlowFlashMode {
        flash.unavailability == nil ? effectiveFlashMode : .off
    }

    /// Whether the Flash indicator is lit, yellow like the stock one: the next photo fires the flash, in On, and in
    /// Auto while the scene is dark enough for it.
    var isFlashLit: Bool {
        switch photoFlashMode {
        case .alwaysOn: true
        case .auto: flash.isScene
        case .off: false
        }
    }

    /// Why the flash of a camera that offers one cannot fire now, nil while it can: the Flash indicator then shows the
    /// flash unavailable, and a tap on it says why.
    var flashUnavailability: FlashUnavailability? {
        isFlashSelectable ? flash.unavailability : nil
    }

    /// The Flash indicator: says why the flash cannot fire while it cannot, and moves to the next mode otherwise. A
    /// camera that offers no flash takes no tap.
    func flashIndicatorTapped() {
        guard flashUnavailability == nil else {
            flash.explainUnavailability()
            return
        }
        cycleFlash()
    }

    /// Takes whether the scene of the running camera is dark enough for the flash in the chosen mode.
    func flashSceneChanged(_ isFlashScene: Bool) {
        flash.sceneChanged(isFlashScene)
    }

    /// Takes whether the flash of the running camera can fire. A flash that can again closes the explanation.
    func flashAvailabilityChanged(_ availability: FlashAvailability) {
        flash.availabilityChanged(availability)
    }

    /// Closes the explanation of why the flash cannot fire.
    func dismissFlashExplanation() {
        flash.dismissExplanation()
    }

    /// Has the running camera monitor its scene for the flash as the next photo would be taken: in the chosen mode,
    /// and in the format the capture uses, whose quality prioritization moves the light level the flash fires at.
    func monitorFlashScene() {
        service.monitorFlashScene(for: flashMode, format: effectivePhotoFormat)
    }

    /// Runs a change of the settings, and has the camera monitor its scene again when the change moved the format of
    /// the next photo. Returns what the change returns.
    func followingCaptureFormat<Value>(_ change: () -> Value) -> Value {
        let format = effectivePhotoFormat
        let value = change()
        if effectivePhotoFormat != format {
            monitorFlashScene()
        }
        return value
    }
}
