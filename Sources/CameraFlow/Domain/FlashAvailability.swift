//
//  FlashAvailability.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// Whether the flash of the camera in the viewfinder can fire now, as the camera reports it.
enum FlashAvailability: Sendable, Equatable {
    case available
    /// The flash cannot fire for a while, for this reason.
    case unavailable(FlashUnavailability)
}

/// Why the flash cannot fire for a while.
enum FlashUnavailability: Sendable, Equatable {
    /// The device is too hot: the flash waits until it has cooled down.
    case heat
    /// The battery cannot give the flash its power: the flash waits until the battery is charged.
    case power
}
