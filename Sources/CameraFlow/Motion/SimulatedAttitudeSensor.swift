//
//  SimulatedAttitudeSensor.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import UIKit
#endif

/// The attitude of a phone without motion sensors to read, for the simulator and the fixtures: held upright the
/// way the device is held, turned on by the quarter of the fixture. On iOS the device is the one `UIDevice`
/// reports, which the simulator turns. Elsewhere it stands upright in portrait.
@MainActor
final class SimulatedAttitudeSensor: DeviceAttitudeSensor {
    private let orientation: CameraOrientation
    #if os(iOS)
    private var observer: (any NSObjectProtocol)?
    /// The quarter the device was last held in.
    private var deviceOrientation = CameraOrientation.portrait
    #endif

    init(orientation: CameraOrientation) {
        self.orientation = orientation
    }

    /// Reports the attitude at once, and again whenever the device turns to another quarter.
    func start(_ report: @escaping @MainActor (DeviceGravity) -> Void) {
        #if os(iOS)
        stop()
        let device = UIDevice.current
        device.beginGeneratingDeviceOrientationNotifications()
        deviceOrientation = Self.quarter(of: device.orientation) ?? .portrait
        report(.upright(in: orientation.turned(by: deviceOrientation)))
        observer = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: device,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.deviceTurned(report)
            }
        }
        #else
        report(.upright(in: orientation))
        #endif
    }

    func stop() {
        #if os(iOS)
        guard let observer else { return }
        NotificationCenter.default.removeObserver(observer)
        self.observer = nil
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        #endif
    }

    #if os(iOS)
    /// A device laid flat or in no known quarter keeps the quarter it was held in.
    private func deviceTurned(_ report: @MainActor (DeviceGravity) -> Void) {
        guard let quarter = Self.quarter(of: UIDevice.current.orientation), quarter != deviceOrientation else { return }
        deviceOrientation = quarter
        report(.upright(in: orientation.turned(by: quarter)))
    }

    private static func quarter(of deviceOrientation: UIDeviceOrientation) -> CameraOrientation? {
        switch deviceOrientation {
        case .portrait: .portrait
        case .landscapeLeft: .landscapeLeft
        case .landscapeRight: .landscapeRight
        case .portraitUpsideDown: .upsideDown
        case .faceUp, .faceDown, .unknown: nil
        @unknown default: nil
        }
    }
    #endif
}
