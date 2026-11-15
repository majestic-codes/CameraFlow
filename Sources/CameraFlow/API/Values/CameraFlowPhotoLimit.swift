//
//  CameraFlowPhotoLimit.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The most photos one set of the flow holds, camera and library together. The photos the camera is still
/// processing count against it, so the shutter takes no photo the set has no room for.
///
/// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
/// needs no `default`.
public enum CameraFlowPhotoLimit: Sendable, Hashable {
    /// As many photos as the user adds.
    case unlimited
    /// At most this many photos, at least 1: a flow created with fewer stops the program.
    case maximum(Int)

    /// One photo: the same flow with a limit of one.
    public static let single = Self.maximum(1)

    /// Stops the program on a limit no set can honour.
    /// - Precondition: a `maximum` is at least 1.
    func validate() {
        if case let .maximum(count) = self {
            precondition(count >= 1, "CameraFlowPhotoLimit.maximum must be at least 1, not \(count)")
        }
    }
}
