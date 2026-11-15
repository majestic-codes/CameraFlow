//
//  ExitConfirmation.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What leaving the flow would lose, for the alert that asks first.
struct ExitConfirmation: Equatable, Sendable {
    /// The photos of the set and the photos the camera took that are on their way into it.
    let photoCount: Int
    /// Whether photos taken with the camera that exist nowhere else are among them: the ones on their way, and the
    /// ones not saved to the photo library right after their shot.
    let hasCameraPhotos: Bool
}
