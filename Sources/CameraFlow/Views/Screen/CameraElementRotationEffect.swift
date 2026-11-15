//
//  CameraElementRotationEffect.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

private struct CameraElementRotationKey: EnvironmentKey {
    static let defaultValue = CameraElementRotation.portrait
}

extension EnvironmentValues {
    /// The turn of the camera elements that stay upright as the phone rotates. `CameraFlowScreen` sets it.
    var cameraElementRotation: CameraElementRotation {
        get { self[CameraElementRotationKey.self] }
        set { self[CameraElementRotationKey.self] = newValue }
    }
}

extension View {

    /// Turns the view about its own centre so that it stays upright as the phone rotates. Apply it before the view
    /// is moved into place, so that the centre is the element's own.
    func rotatesWithDevice() -> some View {
        modifier(CameraElementRotating(turnsInLandscape: true, anchor: .center))
    }

    /// Turns the view half a turn about an anchor while the phone is upside down, and leaves it in landscape.
    func turnsUpsideDownWithDevice(around anchor: UnitPoint) -> some View {
        modifier(CameraElementRotating(turnsInLandscape: false, anchor: anchor))
    }
}

private struct CameraElementRotating: ViewModifier {
    let turnsInLandscape: Bool
    let anchor: UnitPoint
    @Environment(\.cameraElementRotation) private var rotation

    func body(content: Content) -> some View {
        let degrees = turnsInLandscape ? rotation.degrees : rotation.halfTurnDegrees
        content.animation(CameraMotion.Rotation.element) { content in
            content.rotationEffect(.degrees(degrees), anchor: anchor)
        }
    }
}
#endif
