//
//  CapturedPhoto.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation
import Foundation

/// How the file in `CapturedPhoto.imageData` is encoded.
enum PhotoCaptureEncoding: Sendable, Equatable {
    case heif
    /// Used for the HEIF setting when the camera cannot encode HEVC.
    case jpeg
    /// A DNG.
    case appleProRAW
}

/// A part of a capture the camera could not deliver while the photo itself came through.
enum CapturedPhotoLoss: Sendable, Equatable {
    /// The movie of a Live Photo: the photo is a still.
    case livePhotoMovie
    /// The frame of the camera in the circle: the photo has no circle.
    case circleCameraFrame
}

/// One photo as the camera delivered it.
///
/// `imageData` is what `AVCapturePhoto.fileDataRepresentation()` produced, untouched. The request's location comes
/// next to it, for `PhotoCapturePipeline` to write into the file. A Live Photo comes as two files: the still in
/// `imageData` and the movie at `livePhotoMovieURL`, in the temporary directory. `PhotoCapturePipeline` takes over
/// the movie file.
struct CapturedPhoto: Sendable, Equatable {
    let imageData: Data
    let encoding: PhotoCaptureEncoding
    let livePhotoMovieURL: URL?
    /// Where the photo was taken, not yet in `imageData`. Nil for none.
    var location: CLLocation?
    /// The frame of the camera in the circle, taken with the photo by a dual camera, nil for a single camera.
    var circleCameraFrame: CircleCameraFrame?
    /// The parts of the capture that failed while the photo came through, none for a whole capture.
    var losses: [CapturedPhotoLoss] = []
}

/// The frame of the camera in the circle of a dual capture.
struct CircleCameraFrame: Sendable, Equatable {
    /// The photo file of the camera in the circle as it was taken: never mirrored, upright by its orientation.
    let imageData: Data
    /// Whether the viewfinder showed the main camera mirrored, as it shows the front camera, while its photo is not:
    /// the copy puts the circle at the mirrored place, over the part of the picture it covered on the screen.
    let isViewfinderMirrored: Bool
    /// How many quarter turns clockwise take the viewfinder's picture to the upright main photo: 0 for a photo
    /// taken in portrait, 3 for the top of the phone to the left.
    let viewfinderQuarterTurns: Int
}
