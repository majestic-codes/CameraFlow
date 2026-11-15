//
//  CameraHaptics.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// A moment of the camera screen that the stock camera marks with a haptic.
enum CameraHapticEvent: Equatable, Sendable {
    /// The zoom dial passed a lens factor, or a whole factor between the two longest lenses.
    case dialTick
    /// A control panel tile opened its sub-panel.
    case settingOpened
    /// A sub-panel option changed the setting.
    case optionSelected
    /// The flip button switched between the back and the front camera.
    case cameraFlipped
    /// The switch between the shooting and the review settled on the other mode.
    case modeSelected
    /// The switch was pulled towards the review while the set is empty.
    case modeRefused
}

/// Plays the camera's haptics. The model decides when; an implementation decides how they feel.
@MainActor
protocol CameraHaptics: AnyObject {

    func play(_ event: CameraHapticEvent)
    /// Readies the haptic of an event that likely comes in a moment, as the gesture that may end in it begins, so
    /// it plays without delay. It stays ready for a few seconds.
    func prepare(for event: CameraHapticEvent)
}
