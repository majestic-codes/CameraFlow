//
//  CaptureDeviceControl.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation
import os

/// Changes to a capture device, each made under its configuration lock. Called on the session queue.
enum CaptureDeviceControl {
    private static let logger = Logger.camera("CaptureDeviceControl")

    /// Zooms to a factor in the device's own units, clamped to what the device accepts: at once, or as a ramp
    /// when a rate is given.
    static func setZoom(_ deviceFactor: CGFloat, rampRate: Float?, on device: AVCaptureDevice) {
        let lowest = device.minAvailableVideoZoomFactor
        let clamped = min(max(deviceFactor, lowest), device.maxAvailableVideoZoomFactor)
        change(device) { device in
            if let rampRate {
                device.ramp(toVideoZoomFactor: clamped, withRate: rampRate)
            } else {
                if device.isRampingVideoZoom {
                    device.cancelVideoZoomRamp()
                }
                device.videoZoomFactor = clamped
            }
        }
    }

    /// Focuses and exposes once at a point in the device's coordinates. A tap watches the picture for a change that
    /// calls for focusing by itself again, and a lock does not.
    static func focus(at devicePoint: CGPoint, on device: AVCaptureDevice, watchesSubjectArea: Bool) {
        change(device) { device in
            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .autoExpose
            }
            device.isSubjectAreaChangeMonitoringEnabled = watchesSubjectArea
        }
    }

    /// Whether the camera has settled since it was asked to focus and expose once at a point.
    static func hasSettled(_ device: AVCaptureDevice) -> Bool {
        CaptureFocusLockWait.hasSettled(
            isAdjustingFocus: device.isAdjustingFocus,
            isAdjustingExposure: device.isAdjustingExposure,
            isFocusingOnce: device.focusMode == .autoFocus,
            isExposingOnce: device.exposureMode == .autoExpose
        )
    }

    /// Holds the focus and the exposure where the camera settled, each of the two that the camera can lock at a
    /// point (`CaptureDeviceInspector.lockableAdjustments(of:)`), as its photo capabilities say.
    static func lockFocusAndExposure(of device: AVCaptureDevice) {
        guard let adjustments = CaptureDeviceInspector.lockableAdjustments(of: device) else { return }
        change(device) { device in
            if adjustments.locksFocus {
                device.focusMode = .locked
            }
            if adjustments.locksExposure {
                device.exposureMode = .locked
            }
        }
    }

    /// Watches the picture again for a change that calls for focusing by itself, as after a tap.
    static func watchSubjectArea(of device: AVCaptureDevice) {
        change(device) { $0.isSubjectAreaChangeMonitoringEnabled = true }
    }

    /// Focuses and exposes by itself at the centre of the picture, as the camera does before a tap, and stops
    /// watching the picture.
    static func resetFocus(on device: AVCaptureDevice) {
        let centre = CGPoint(x: 0.5, y: 0.5)
        change(device) { device in
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = centre
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = centre
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.isSubjectAreaChangeMonitoringEnabled = false
        }
    }

    /// Puts the camera on its main lens: the displayed 1×, a device factor of `1 / displayMultiplier`.
    static func zoomToMainLens(_ device: AVCaptureDevice, displayMultiplier: CGFloat) {
        let mainFactor = 1 / displayMultiplier
        change(device) { $0.videoZoomFactor = mainFactor }
    }

    static func setExposureBias(_ bias: Float, on device: AVCaptureDevice) {
        let clamped = min(max(bias, device.minExposureTargetBias), device.maxExposureTargetBias)
        change(device) { $0.setExposureTargetBias(clamped) }
    }

    /// Runs the camera at the frame rates for the system pressure on it: slower from the serious level on, which
    /// puts off the pause to cool down, and as fast as its format runs again once the pressure is low.
    static func throttleFrameRate(of device: AVCaptureDevice, under pressure: CaptureSystemPressure) {
        let supported = device.activeFormat.videoSupportedFrameRateRanges.map { $0.minFrameRate...$0.maxFrameRate }
        let rates = CaptureFrameRateThrottle.frameRates(under: pressure, supported: supported)
        if rates == nil, pressure != .low {
            logger.error("The format of the camera cannot run slower under system pressure")
        }
        let shortestFrame = rates.map { CMTime(value: 1, timescale: CMTimeScale($0.upperBound)) } ?? .invalid
        let longestFrame = rates.map { CMTime(value: 1, timescale: CMTimeScale($0.lowerBound)) } ?? .invalid
        change(device) { device in
            device.activeVideoMinFrameDuration = shortestFrame
            device.activeVideoMaxFrameDuration = longestFrame
        }
    }

    /// Runs a change under the device's configuration lock. A device that cannot be locked is left as it is.
    static func change(_ device: AVCaptureDevice, _ body: (AVCaptureDevice) -> Void) {
        do {
            try device.lockForConfiguration()
        } catch {
            logger.error("Cannot lock the camera for configuration: \(error.localizedDescription, privacy: .public)")
            return
        }
        body(device)
        device.unlockForConfiguration()
    }
}
#endif
