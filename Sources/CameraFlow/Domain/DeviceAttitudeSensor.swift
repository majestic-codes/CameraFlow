//
//  DeviceAttitudeSensor.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The sensor that tells how the phone is held. It knows nothing of the camera that runs, of the interface
/// orientation or of the rotation lock.
@MainActor
protocol DeviceAttitudeSensor: AnyObject {

    /// Starts reporting gravity on the main actor, until `stop()`.
    func start(_ report: @escaping @MainActor (DeviceGravity) -> Void)
    func stop()
}
