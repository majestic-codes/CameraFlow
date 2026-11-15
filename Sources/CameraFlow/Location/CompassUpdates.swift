//
//  CompassUpdates.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What the compass of the photos' direction runs on its Core Location manager.
struct CompassUpdates {
    /// The readings of the compass.
    let heading: Bool
    /// The location, without which Core Location gives the manager no true heading.
    let location: Bool

    /// The updates of a compass that runs (`isActive`): the heading on a device that has a compass, and the location
    /// with it where the photos record their location (`followsLocation`) and the user granted access. The compass
    /// never asks for access.
    init(isActive: Bool, hasCompass: Bool, followsLocation: Bool, authorization: LocationAuthorization) {
        heading = isActive && hasCompass
        location = heading && followsLocation && authorization == .authorized
    }
}
