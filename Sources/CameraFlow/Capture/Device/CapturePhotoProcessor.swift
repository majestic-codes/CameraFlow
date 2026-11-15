//
//  CapturePhotoProcessor.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation
import CoreLocation
import os

/// Collects the parts of one capture (the still, the Live Photo movie) and hands them over once the output
/// reports the capture finished: the photo whenever its still came through, as a still when only its movie failed.
/// AVFoundation calls a delegate serially, which is what makes the unchecked sendability hold.
///
/// The file is the photo's own `fileDataRepresentation()`, never a customized one: a replacement metadata
/// dictionary drops the keys the file writer adds on its own (most of the EXIF and MakerApple keys), so the
/// location travels next to the file and `PhotoCapturePipeline` adds it.
final class CapturePhotoProcessor: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let encoding: PhotoCaptureEncoding
    private let location: CLLocation?
    /// Where the capture asked for the Live Photo movie, nil for a still.
    private let requestedMovieURL: URL?
    private let completion: @Sendable (Result<CapturedPhoto, any Error>) -> Void
    private var parts: CaptureParts
    /// Whether the still or the capture failed because the device is full, which the failure then says.
    private var isOutOfSpace = false

    private static let logger = Logger.camera("CapturePhotoProcessor")

    init(
        encoding: PhotoCaptureEncoding,
        location: CLLocation?,
        requestedMovieURL: URL?,
        completion: @escaping @Sendable (Result<CapturedPhoto, any Error>) -> Void
    ) {
        self.encoding = encoding
        self.location = location
        self.requestedMovieURL = requestedMovieURL
        self.completion = completion
        parts = CaptureParts(asksForMovie: requestedMovieURL != nil)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        if let error {
            parts.stillFailure = error.localizedDescription
            isOutOfSpace = isOutOfSpace || Self.isDiskFull(error)
            return
        }
        parts.imageData = photo.fileDataRepresentation()
    }

    // The delegate method's signature is AVFoundation's.
    // swiftlint:disable:next function_parameter_count
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
        duration: CMTime,
        photoDisplayTime: CMTime,
        resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: (any Error)?
    ) {
        if let error {
            parts.movieFailure = error.localizedDescription
            return
        }
        parts.movieURL = outputFileURL
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: (any Error)?
    ) {
        let captureFailure = error?.localizedDescription
        isOutOfSpace = isOutOfSpace || error.map(Self.isDiskFull) == true
        switch parts.photo(captureFailure: captureFailure, encoding: encoding, location: location) {
        case let .success(photo):
            if parts.isMovieLost {
                let reason = parts.movieFailure ?? captureFailure ?? "The movie did not come"
                Self.logger.error("The photo goes as a still, its Live Photo movie failed: \(reason, privacy: .public)")
                discardMovie()
            }
            completion(.success(photo))
        case let .failure(failure):
            discardMovie()
            completion(.failure(isOutOfSpace ? CameraServiceError.notEnoughStorage : failure))
        }
    }

    private static func isDiskFull(_ error: any Error) -> Bool {
        (error as? AVError)?.code == .diskFull
    }

    /// Deletes what was written of the movie of a capture that hands it over to nobody.
    private func discardMovie() {
        guard let movieURL = parts.movieURL ?? requestedMovieURL,
              FileManager.default.fileExists(atPath: movieURL.path) else { return }
        CaptureFileStore.discard(movieURL)
    }
}
#endif
