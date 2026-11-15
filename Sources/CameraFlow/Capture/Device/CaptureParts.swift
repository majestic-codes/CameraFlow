//
//  CaptureParts.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation
import Foundation

/// The parts of one capture as the camera reports them, and the photo they make once the capture has finished: the
/// photo whenever its still came through, a still without its Live Photo movie when only the movie failed.
struct CaptureParts {
    /// Whether the capture asked for a Live Photo movie.
    let asksForMovie: Bool
    /// The file of the still, nil until it came.
    var imageData: Data?
    /// Why the still failed, nil while it has not.
    var stillFailure: String?
    /// The file of the movie, nil until it came.
    var movieURL: URL?
    /// Why the movie failed, nil while it has not.
    var movieFailure: String?

    /// Whether the movie the capture asked for failed or never came.
    var isMovieLost: Bool {
        asksForMovie && (movieURL == nil || movieFailure != nil)
    }

    /// The photo of the finished capture, given why the capture as a whole failed, nil when it did not. A failure
    /// of the capture that comes with a lost movie is the movie's.
    func photo(
        captureFailure: String?,
        encoding: PhotoCaptureEncoding,
        location: CLLocation?
    ) -> Result<CapturedPhoto, CameraServiceError> {
        if let stillFailure {
            return .failure(.captureFailed(stillFailure))
        }
        guard let imageData else {
            return .failure(captureFailure.map(CameraServiceError.captureFailed) ?? .noImageData)
        }
        if let captureFailure, !isMovieLost {
            return .failure(.captureFailed(captureFailure))
        }
        let photo = CapturedPhoto(
            imageData: imageData,
            encoding: encoding,
            livePhotoMovieURL: isMovieLost ? nil : movieURL,
            location: location,
            losses: isMovieLost ? [.livePhotoMovie] : []
        )
        return .success(photo)
    }
}
