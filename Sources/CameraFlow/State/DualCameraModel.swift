//
//  DualCameraModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Observation

/// The circle of the second camera in the viewfinder: whether the screen has it and its toggle, whether it is on,
/// which camera it shows and where the viewfinder shows it. `PhotoCameraModel` turns it on and off, swaps the two
/// cameras, hands over which ones run whenever a camera has started and whether the flow uses the camera.
@MainActor
@Observable
final class DualCameraModel {
    /// Whether the screen has the circle: the app lets the user switch it or fixed it on, and the device can run the
    /// two cameras. It goes for good when the two cameras fail to start together.
    private(set) var isAvailable: Bool
    /// Whether the user may switch the circle: its indicator in the top bar and its tile.
    let isUserAdjustable: Bool
    /// True while the camera switches between the pair and one camera.
    private(set) var isSwitching = false
    /// Whether the flow uses the camera, so the circle may be switched: its access was granted and it is neither
    /// stopped nor closed.
    private(set) var isCameraActive = false
    /// Whether the two cameras run together now.
    private(set) var isOn = false
    /// The camera the circle shows: the one that is not in the viewfinder.
    private(set) var circlePosition = CameraPosition.front
    /// Where the viewfinder shows the circle, as the screen last laid it out. Nil until it is laid out.
    @ObservationIgnored private(set) var circle: DualCameraCircle?
    /// The covers of the pictures on screen, which the circle's picture joins while it shows.
    @ObservationIgnored let pictureCovers: CameraPictureCovers

    init(setting: CameraFlowSetting<Bool>, isSupported: Bool, pictureCovers: CameraPictureCovers) {
        isAvailable = setting.canBeOn && isSupported
        isUserAdjustable = setting.isUserAdjustable
        self.pictureCovers = pictureCovers
    }

    /// Whether the screen shows the toggle: the user may switch a circle the screen has.
    var isToggleOffered: Bool {
        isAvailable && isUserAdjustable
    }

    /// Whether the toggle can be used now: it is offered, the flow uses the camera and no switch is under way.
    var isToggleEnabled: Bool {
        isToggleOffered && isCameraActive && !isSwitching
    }

    /// The place of the circle the viewfinder has laid out, which a capture composites the circle's frame at.
    func circleLaidOut(_ circle: DualCameraCircle) {
        self.circle = circle
    }

    /// A camera has started at a side of the viewfinder, with the other camera in the circle or alone.
    func cameraStarted(at position: CameraPosition, isDualCameraOn: Bool) {
        isOn = isDualCameraOn
        circlePosition = position.flipped
    }

    /// The flow began or ended using the camera.
    func cameraActivityChanged(isActive: Bool) {
        isCameraActive = isActive
    }

    func beginSwitching() {
        isSwitching = true
    }

    func endSwitching() {
        isSwitching = false
    }

    /// The two cameras failed to start together, so the screen stops offering the circle.
    func becameUnavailable() {
        isAvailable = false
    }
}
