//
//  ManualAttitudeSensor.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

@testable import CameraFlow

/// An attitude sensor that reports only the gravity a test hands it.
@MainActor
final class ManualAttitudeSensor: DeviceAttitudeSensor {
    private var report: (@MainActor (DeviceGravity) -> Void)?

    var isRunning: Bool {
        report != nil
    }

    func start(_ report: @escaping @MainActor (DeviceGravity) -> Void) {
        self.report = report
    }

    func stop() {
        report = nil
    }

    /// Delivers a reading as the sensor would. A sensor that does not run delivers nothing.
    func simulate(_ gravity: DeviceGravity) {
        report?(gravity)
    }
}
