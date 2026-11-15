//
//  CameraFlash.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The flash of the running camera as the camera reports it: whether the scene is dark enough for it and whether it
/// can fire, and the explanation the screen shows of a flash that cannot. Until a camera reports otherwise the scene
/// needs no flash and the flash can fire.
struct CameraFlash {
    /// Whether the scene is dark enough for the flash in the chosen mode.
    private(set) var isScene = false
    private(set) var availability = FlashAvailability.available
    /// Why the flash cannot fire, while the screen explains it.
    private(set) var explanation: FlashUnavailability?

    /// Why the flash cannot fire now, nil while it can.
    var unavailability: FlashUnavailability? {
        guard case let .unavailable(reason) = availability else { return nil }
        return reason
    }

    mutating func sceneChanged(_ isScene: Bool) {
        self.isScene = isScene
    }

    /// A flash that can fire again ends the explanation of why it could not.
    mutating func availabilityChanged(_ availability: FlashAvailability) {
        self.availability = availability
        if availability == .available {
            explanation = nil
        }
    }

    /// Explains why the flash cannot fire, while it cannot.
    mutating func explainUnavailability() {
        explanation = unavailability
    }

    mutating func dismissExplanation() {
        explanation = nil
    }
}
