//
//  CaptureAdmission.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// Decides whether the shutter may take another photo.
@MainActor
protocol CaptureAdmission: AnyObject {

    /// Why the shutter takes no other photo now, beside the photos already on their way from it, nil while it may.
    func captureRefusal(photosInFlight: Int) -> CameraServiceError?
}
