//
//  CaptureDeviceInspector.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation
import OSLog

/// Reads what a capture device and the photo output can do, in the screen's terms.
enum CaptureDeviceInspector {
    private static let logger = Logger.camera("CaptureDeviceInspector")

    /// Diagonal of a 35 mm film frame in millimetres.
    private static let filmDiagonal = 43.27
    /// `AVCaptureSession.InterruptionReason.sensitiveContentMitigationActivated`, iOS 26.
    private static let sensitiveContentMitigationReason = 6
    /// `AVCaptureDevice.SystemPressureState.Factors.batteryStress`, iOS 27.
    private static let batteryStressFactor = AVCaptureDevice.SystemPressureState.Factors(rawValue: 1 << 4)

    /// The kinds of camera the flow runs, the one with the most lenses first.
    static let deviceTypes: [AVCaptureDevice.DeviceType] = [
        .builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera
    ]

    /// The camera at a position: the virtual device with the most lenses where there is one. A virtual device
    /// with an ultra wide switches to it at close range by itself, which is the automatic macro.
    static func camera(at position: CameraPosition) -> AVCaptureDevice? {
        let devicePosition: AVCaptureDevice.Position = position == .back ? .back : .front
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: devicePosition
        )
        return discovery.devices.first
    }

    /// What a camera can do for photos through its photo output. The flash modes are the ones the output offers: a
    /// front camera with the flash of the screen offers it there, whatever the device says of a flash of its own.
    static func photoCapabilities(
        of device: AVCaptureDevice,
        output: AVCapturePhotoOutput
    ) -> PhotoCaptureCapabilities {
        let rawFormats = output.availableRawPhotoPixelFormatTypes
        let hasProRAWFormat = rawFormats.contains(where: AVCapturePhotoOutput.isAppleProRAWPixelFormat)
        let hasProRAW = output.isAppleProRAWEnabled && hasProRAWFormat
        let flashModes = output.supportedFlashModes.compactMap(flashMode)
        let offered = flashModes.map(\.rawValue).joined(separator: ", ")
        let hasFlash = device.hasFlash
        logger.debug("Flash modes: \(offered, privacy: .public), a flash of its own: \(hasFlash, privacy: .public)")
        return PhotoCaptureCapabilities(
            flashModes: flashModes.contains(.off) ? flashModes : flashModes + [.off],
            isLivePhotoSupported: output.isLivePhotoCaptureEnabled,
            exposureBiasRange: exposureBiasRange(of: device),
            formats: hasProRAW ? [.heif, .raw] : [.heif],
            encodesHEVC: output.availablePhotoCodecTypes.contains(.hevc),
            resolution: resolution(of: device),
            lockableAdjustments: lockableAdjustments(of: device)
        )
    }

    /// What the device can hold at a point for AE/AF Lock: the focus where it focuses once at a point and locks the
    /// focus, the exposure where it exposes once at a point and locks the exposure. Nil for a device that can do
    /// neither.
    static func lockableAdjustments(of device: AVCaptureDevice) -> LockableAdjustments? {
        let focusModes = [AVCaptureDevice.FocusMode.autoFocus, .locked]
        let exposureModes = [AVCaptureDevice.ExposureMode.autoExpose, .locked]
        let locksFocus = device.isFocusPointOfInterestSupported && focusModes.allSatisfy(device.isFocusModeSupported)
        let locksExposure = device.isExposurePointOfInterestSupported
            && exposureModes.allSatisfy(device.isExposureModeSupported)
        return LockableAdjustments(locksFocus: locksFocus, locksExposure: locksExposure)
    }

    /// Maps by raw value so that reasons newer than the deployment target (6 is iOS 26) need no availability check.
    /// A reason this code does not know, or none at all, is logged and kept as another reason, -1 for none.
    static func interruption(rawReason: Int?) -> CameraInterruption {
        guard let rawReason else {
            logger.error("The capture session was interrupted without a reason")
            return .other(-1)
        }
        switch rawReason {
        case AVCaptureSession.InterruptionReason.videoDeviceNotAvailableInBackground.rawValue:
            return .cameraUnavailableInBackground
        case AVCaptureSession.InterruptionReason.audioDeviceInUseByAnotherClient.rawValue:
            return .audioInUseByAnotherClient
        case AVCaptureSession.InterruptionReason.videoDeviceInUseByAnotherClient.rawValue:
            return .cameraInUseByAnotherClient
        case AVCaptureSession.InterruptionReason.videoDeviceNotAvailableWithMultipleForegroundApps.rawValue:
            return .cameraUnavailableBesideOtherApps
        case AVCaptureSession.InterruptionReason.videoDeviceNotAvailableDueToSystemPressure.rawValue:
            return .cameraUnavailableUnderPressure
        case Self.sensitiveContentMitigationReason:
            return .sensitiveContentMitigationActivated
        default:
            logger.error("Unknown interruption reason \(rawReason, privacy: .public) of the capture session")
            return .other(rawReason)
        }
    }

    /// The error that stopped a session, in the system's words, whatever its domain. A reset of the media services is
    /// the one a new start recovers from.
    static func runtimeError(_ error: (any Error)?) -> CameraRuntimeError {
        guard let error else {
            let message = "The capture session stopped without an error"
            logger.error("\(message, privacy: .public)")
            return CameraRuntimeError(message: message, isRecoverable: false)
        }
        logger.error("The capture session stopped: \(String(describing: error), privacy: .public)")
        let isRecoverable = (error as? AVError)?.code == .mediaServicesWereReset
        return CameraRuntimeError(message: error.localizedDescription, isRecoverable: isRecoverable)
    }

    /// Whether the flash of a device can fire now. A flash that cannot waits for the battery where a factor of the
    /// system pressure is about power, and for the device to cool down otherwise. A device without a flash of its own
    /// reports none available, so it counts as available: its photo output alone says whether it offers a flash.
    static func flashAvailability(of device: AVCaptureDevice) -> FlashAvailability {
        guard device.hasFlash, !device.isFlashAvailable else { return .available }
        let factors = device.systemPressureState.factors
        let isAboutPower = factors.contains(.peakPower) || factors.contains(batteryStressFactor)
        return .unavailable(isAboutPower ? .power : .heat)
    }

    /// How hard the system presses a camera. A level newer than this code counts as a serious one.
    static func pressure(of state: AVCaptureDevice.SystemPressureState) -> CaptureSystemPressure {
        switch state.level {
        case .nominal, .fair:
            return .low
        case .serious:
            return .serious
        case .critical, .shutdown:
            return .critical
        default:
            logger.error("Unknown system pressure level \(state.level.rawValue, privacy: .public)")
            return .serious
        }
    }

    static func optics(of device: AVCaptureDevice) -> LensOptics {
        let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat($0.doubleValue) }
        let physicalDevices = (device.isVirtualDevice ? device.constituentDevices : [device])
            .sorted { $0.activeFormat.videoFieldOfView > $1.activeFormat.videoFieldOfView }
        let deviceFactors = [1] + switchOvers
        let lenses = zip(deviceFactors, physicalDevices).map { deviceFactor, physicalDevice in
            LensOptics.PhysicalLens(
                deviceFactor: deviceFactor,
                cropFactors: physicalDevice.activeFormat.secondaryNativeResolutionZoomFactors,
                focalLength: focalLength(of: physicalDevice)
            )
        }
        return LensOptics(
            lenses: lenses,
            displayMultiplier: displayMultiplier(of: device, switchOvers: switchOvers),
            maximumDeviceFactor: device.maxAvailableVideoZoomFactor,
            recommendedMaximumDeviceFactor: recommendedMaximumZoomFactor(of: device)
        )
    }

    /// The top of the zoom range the system recommends for the active format, on iOS 18 and later.
    private static func recommendedMaximumZoomFactor(of device: AVCaptureDevice) -> CGFloat? {
        guard #available(iOS 18, *) else { return nil }
        return device.activeFormat.systemRecommendedVideoZoomRange?.upperBound
    }

    /// The flash mode of the screen for one of the camera, nil for a mode this code does not know, which is logged.
    private static func flashMode(_ deviceMode: AVCaptureDevice.FlashMode) -> CameraFlowFlashMode? {
        switch deviceMode {
        case .auto:
            return .auto
        case .on:
            return .alwaysOn
        case .off:
            return .off
        @unknown default:
            logger.error("Unknown flash mode \(deviceMode.rawValue, privacy: .public) of the camera is left out")
            return nil
        }
    }

    /// Device limits, narrowed to the format's recommended range on iOS 18 and later.
    private static func exposureBiasRange(of device: AVCaptureDevice) -> ClosedRange<Double> {
        let deviceRange = Double(device.minExposureTargetBias)...Double(device.maxExposureTargetBias)
        if #available(iOS 18, *), let recommended = device.activeFormat.systemRecommendedExposureBiasRange {
            let recommendedRange = Double(recommended.lowerBound)...Double(recommended.upperBound)
            return recommendedRange.clamped(to: deviceRange)
        }
        return deviceRange
    }

    /// The photo size of the format the flow shoots at: the size every photo asks for and the photo output is set up
    /// for.
    static func resolution(of device: AVCaptureDevice) -> PhotoCaptureResolution? {
        let supported = device.activeFormat.supportedMaxPhotoDimensions
        let sizes = supported.map { "\($0.width)x\($0.height)" }.joined(separator: ", ")
        logger.debug("Photo sizes of the active format: \(sizes, privacy: .public)")
        return PhotoCaptureResolution.offered(among: supported.map { (width: $0.width, height: $0.height) })
    }

    private static func displayMultiplier(of device: AVCaptureDevice, switchOvers: [CGFloat]) -> CGFloat {
        if #available(iOS 18, *) {
            return device.displayVideoZoomFactorMultiplier
        }
        let hasUltraWide = device.constituentDevices.contains { $0.deviceType == .builtInUltraWideCamera }
        guard hasUltraWide, let mainFactor = switchOvers.first else { return 1 }
        return 1 / mainFactor
    }

    /// 35 mm equivalent focal length from the horizontal field of view of a 4:3 frame.
    private static func focalLength(of device: AVCaptureDevice) -> Int {
        let halfAngle = Double(device.activeFormat.videoFieldOfView) / 2 * .pi / 180
        let halfWidth = filmDiagonal / 2 * 4 / 5
        return Int((halfWidth / tan(halfAngle)).rounded())
    }
}
#endif
