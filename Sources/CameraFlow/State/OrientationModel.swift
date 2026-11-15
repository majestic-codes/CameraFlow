//
//  OrientationModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Observation

/// How the phone is held and how the interface stands, and the turn of the elements that stay upright as the phone
/// rotates.
@MainActor
@Observable
final class OrientationModel {
    /// The turn of the elements that stay upright as the phone rotates: by how the phone is held as seen from the
    /// interface, so nothing turns while the interface itself turns with the phone.
    private(set) var elementRotation = CameraElementRotation.portrait
    /// The quarter the interface stands in: portrait while the flow's own presentation keeps it so, as on iPhone,
    /// and the quarter the system turned it to on iPad.
    private(set) var interfaceOrientation = CameraOrientation.portrait
    /// The quarter the phone is held in, from gravity.
    @ObservationIgnored private(set) var heldOrientation = CameraOrientation.portrait

    /// Turns the upright elements to the quarter the phone is held in under this gravity, whichever camera runs.
    func gravityChanged(to gravity: DeviceGravity) {
        let orientation = gravity.orientation(holding: heldOrientation)
        // Readings keep coming while the phone is still, and only a new quarter may invalidate the views.
        guard orientation != heldOrientation else { return }
        heldOrientation = orientation
        turnElements()
    }

    /// Takes the quarter the interface stands in now, which the elements turn from.
    func interfaceOrientationChanged(to orientation: CameraOrientation) {
        guard orientation != interfaceOrientation else { return }
        interfaceOrientation = orientation
        turnElements()
    }

    private func turnElements() {
        let orientation = heldOrientation.relative(to: interfaceOrientation)
        guard orientation != elementRotation.orientation else { return }
        elementRotation = elementRotation.turned(to: orientation)
    }
}
