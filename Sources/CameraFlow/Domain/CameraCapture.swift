//
//  CameraCapture.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import CoreLocation
import Foundation
import UniformTypeIdentifiers

/// One photo taken by the camera, as files on disk and a small thumbnail.
///
/// The photo is the full file the camera wrote, with all its metadata and auxiliary images (such as the HDR gain
/// map). Nothing large stays in memory, so a set can hold many captures.
///
/// Ownership: the files at `fileURLs` belong to the receiver from the moment the capture is handed over. The
/// receiver moves them somewhere permanent or deletes them, and the camera never touches them again. They sit in a
/// temporary directory of the camera session, which the system may purge. Files of a capture that is never handed
/// over (a failed capture, or one that finishes after the screen went away) are deleted by the camera.
struct CameraCapture: Sendable, Identifiable {
    /// Identifies the capture within the app's lifetime.
    let id: UUID
    /// The photo file: HEIF, JPEG on a camera that cannot encode HEVC, or a DNG for RAW.
    ///
    /// For a 4:3 photo and a RAW photo these are the camera's own bytes. A 16:9 or 1:1 photo is
    /// cropped and encoded again, with its metadata, colour profile, bit depth and gain map carried over. An output
    /// other than the default scales, re-encodes or strips the file as `CameraFlowOutput` describes.
    let fileURL: URL
    /// The full picture for the system photo library when no other file of the capture is it: the camera's photo when
    /// the output scaled, re-encoded or stripped `fileURL`, or for a dual capture the full copy with the circle when
    /// the output changed `dualCameraCopy`. Nil when the library takes `dualCameraCopy` of a dual capture, or
    /// `fileURL` of any other.
    let libraryFileURL: URL?
    /// The type of the file at `fileURL`, such as `.heic`, `.jpeg` or the DNG type.
    let contentType: UTType
    /// A small upright copy of the photo for the interface, at most `thumbnailMaximumPixelSize` on its long side.
    let thumbnail: CGImage
    /// The movie half of a Live Photo, nil for a still photo.
    let livePhotoMovieURL: URL?
    /// The part of the upright photo the viewfinder showed, in unit coordinates (origin top left), when the file
    /// holds more than that; nil when the file is exactly what the viewfinder framed.
    ///
    /// Set for a 16:9 or 1:1 photo the camera cannot crop without losing data: a RAW photo is always handed over
    /// whole, in the sensor's 4:3.
    let framedRegion: CGRect?
    /// The copy of the photo with the second camera's circle of a dual capture, with its type, nil for a capture of
    /// one camera. The thumbnail shows this copy. Upright, with the metadata of the camera's photo, brought to the
    /// output as `fileURL` is, which stays without the circle. Its type is the type of `fileURL` unless the copy is
    /// written in a type of its own, as a HEIC of a photo whose type ImageIO cannot write.
    let dualCameraCopy: CameraFlowPhoto.File?
    /// The output the files were brought to, which a copy with a drawing is brought to as well.
    var output = CameraFlowOutput()
    /// Where the photo was taken, nil for a photo taken without a location. The photo library gets it with the
    /// photo, also where the file cannot carry it.
    var location: CLLocation?
    /// What the photo is handed over without because processing could not write it, such as the copy with the
    /// circle or the Live Photo movie: shown in the same notice as what the camera failed to deliver.
    var losses: [CapturedPhotoLoss] = []

    /// The longest side of `thumbnail`, in pixels.
    static let thumbnailMaximumPixelSize = 288

    /// Every file of the capture.
    var fileURLs: [URL] {
        [fileURL, livePhotoMovieURL, dualCameraCopy?.url, libraryFileURL].compactMap(\.self)
    }
}
