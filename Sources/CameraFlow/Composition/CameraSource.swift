//
//  CameraSource.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The camera a flow runs on.
enum CameraSource: Equatable {
    /// The camera of the device.
    case device
    /// The camera with no hardware, whose photos are synthetic.
    case simulated

    /// The simulated camera stands in where the app asks for it and in the iOS Simulator, which has no camera. A
    /// device always gets its own camera, so one without a camera says that it is unavailable and hands over no
    /// synthetic photo.
    static func resolve(usesSimulatedCamera: Bool, isSimulator: Bool = Self.isSimulator) -> Self {
        usesSimulatedCamera || isSimulator ? .simulated : .device
    }

    /// Whether the code runs in the iOS Simulator.
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}
