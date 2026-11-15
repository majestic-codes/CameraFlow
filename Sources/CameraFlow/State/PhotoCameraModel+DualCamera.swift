//
//  PhotoCameraModel+DualCamera.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

// MARK: - The second camera's circle

extension PhotoCameraModel {

    /// Turns the circle on, with the other camera in it and the one that ran in the viewfinder, or off, back to the
    /// camera of the viewfinder alone, and remembers the switch once it took effect. It waits for a photo that is
    /// being taken, which the camera delivers first. A tap while the camera is being changed is ignored.
    func toggleDualCamera() async {
        guard dualCamera.isToggleEnabled, !changes.isChanging else { return }
        await changes.run {
            guard session.isActive else { return }
            dualCamera.beginSwitching()
            defer { dualCamera.endSwitching() }
            clearNotices()
            focus.clear()
            zoom.closeDial()
            let position = session.position
            let turnsOn = !session.isDualCameraOn
            if turnsOn {
                await startDualCamera(main: position)
            } else {
                await startCamera(at: position)
            }
            if session.isDualCameraOn == turnsOn {
                settings.recordDualCameraChoice(isOn: turnsOn)
            }
        }
    }

    /// The system pressure got too high for two cameras: the camera of the viewfinder goes on alone and the notice
    /// says why. It waits for a change that is under way and for a photo that is being taken, and a pair that is
    /// off by then, or a camera the flow no longer uses, is left alone.
    func dualCameraUnderPressure() async {
        await changes.run {
            guard session.isDualCameraOn, session.isActive else { return }
            dualCamera.beginSwitching()
            defer { dualCamera.endSwitching() }
            shutter.cancelCountdown()
            focus.clear()
            guard await startCamera(at: session.position) else { return }
            notices.showDualCameraNotice(.turnedOffUnderPressure)
        }
    }

    /// Starts the pair with the camera at `main` in the viewfinder, or swaps a pair that runs, and puts every model
    /// on it, and returns whether it runs. The notice names what a pair that comes on over a running camera leaves
    /// out of what that camera took. When it cannot run, the camera that ran before starts alone, the notice says
    /// so, and a device that has no pair that fits stops offering it. It runs inside a change of the camera
    /// (`changes`).
    @discardableResult
    func startDualCamera(main: CameraPosition) async -> Bool {
        let previousPosition = session.position
        let inEffectAlone = session.isDualCameraOn ? nil : settings.inEffect
        zoom.cameraStarting()
        let capabilities: CameraCapabilities
        do {
            capabilities = try await session.startDualCamera(main: main)
        } catch {
            if case .dualCameraUnavailable = error {
                dualCamera.becameUnavailable()
                settings.dualCameraBecameUnavailable()
            }
            await startCamera(at: previousPosition)
            notices.showDualCameraNotice(.unavailable)
            return false
        }
        guard cameraStarted(capabilities) else { return false }
        if let inEffectAlone, let narrowed = settings.dualCameraNarrowedSetting(comparedTo: inEffectAlone) {
            notices.showDualCameraNotice(.settingOff(narrowed))
        }
        return true
    }
}
