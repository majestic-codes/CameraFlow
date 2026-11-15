//
//  CameraFlowCompletion.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 13.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// How the flow ends with photos: when the user accepts the set, or by itself after one photo.
///
/// Under ``afterOnePhoto`` the set holds one photo, whatever ``CameraFlowConfiguration/photoLimit`` says: the photo
/// picker lets the user pick one, and the flow hands it over as soon as it is in, as the check mark would. So the
/// user never sees the review or the markup: the photo comes without a drawing, and with the second camera's circle
/// where it was on. A second quick tap of the shutter takes no photo: the flow ends with the first. A
/// photo that arrives while the exit alert asks waits for the answer: Stay hands it over, Leave deletes it. A Live
/// Photo, a saving to the photo library and the output work as with the check mark: the hand-over waits for a save
/// still running. A shot that fails, a pick that cannot be loaded or a picker closed without a pick leave the flow
/// open, with its notice where there is one, and the cross still leaves it. A save to the photo library that fails at
/// the hand-over leaves it open with its notice too, and the check mark then hands the photo over.
///
/// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
/// needs no `default`.
public enum CameraFlowCompletion: Sendable, Hashable {
    /// The user reviews the set and accepts it with the check mark. The default.
    case userConfirms
    /// The flow ends by itself after one photo taken with the camera or picked from the library.
    case afterOnePhoto
}

extension CameraFlowConfiguration {
    /// The most photos the set holds: one when the flow ends after one photo, the app's limit otherwise.
    var effectivePhotoLimit: CameraFlowPhotoLimit {
        switch completion {
        case .userConfirms: photoLimit
        case .afterOnePhoto: .maximum(1)
        }
    }
}
