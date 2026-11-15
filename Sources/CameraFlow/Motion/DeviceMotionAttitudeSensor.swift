//
//  DeviceMotionAttitudeSensor.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import CoreMotion
import os
import UIKit

/// The attitude of this phone, from the gravity that CoreMotion separates out of its motion sensors. The sensors are
/// read while the app is in the foreground, and again once it comes back from the background.
///
/// Each flow has a sensor of its own, with its own `CMMotionManager` beside any the app runs: the package takes no
/// manager from the app. Its readings come ten times a second, from the start of the camera until the flow closes.
@MainActor
final class DeviceMotionAttitudeSensor: DeviceAttitudeSensor {
    private let motionManager = CMMotionManager()
    private let following = ForegroundFollowing(
        background: UIApplication.didEnterBackgroundNotification,
        foreground: UIApplication.willEnterForegroundNotification
    )

    /// Seconds between two readings. A turn of the phone takes far longer than that.
    private static let updateInterval = 0.1
    private static let logger = Logger.camera("DeviceMotionAttitudeSensor")

    func start(_ report: @escaping @MainActor (DeviceGravity) -> Void) {
        guard motionManager.isDeviceMotionAvailable else {
            Self.logger.error("This device reports no motion, so the camera elements never turn")
            return
        }
        motionManager.deviceMotionUpdateInterval = Self.updateInterval
        following.start { [weak self] isActive in
            self?.follow(isActive, reporting: report)
        }
    }

    func stop() {
        following.stop()
    }

    private func follow(_ isActive: Bool, reporting report: @escaping @MainActor (DeviceGravity) -> Void) {
        guard isActive else {
            motionManager.stopDeviceMotionUpdates()
            return
        }
        // The handler is isolated to the main actor, and the main queue is where it is called.
        motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
            guard let motion else {
                Self.logger.error("A device motion reading failed: \(String(describing: error), privacy: .public)")
                return
            }
            let gravity = motion.gravity
            report(DeviceGravity(towardRightEdge: gravity.x, towardTopEdge: gravity.y, outOfScreen: gravity.z))
        }
    }
}
#endif
