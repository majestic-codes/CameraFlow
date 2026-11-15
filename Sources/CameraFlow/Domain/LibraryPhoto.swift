//
//  LibraryPhoto.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// One photo picked from the photo library, as files on disk and a small thumbnail.
///
/// The file is a copy of the library's, byte for byte, in the directory of the flow, or its output. A Live Photo
/// comes with its movie beside it. The files belong to the receiver, as the files of a `CameraCapture` do.
struct LibraryPhoto: Sendable, Identifiable {
    /// Identifies the photo within the app's lifetime.
    let id: UUID
    let fileURL: URL
    /// The movie half of a Live Photo, nil for a still photo and for a Live Photo under an output that strips the
    /// metadata.
    var livePhotoMovieURL: URL?
    /// The type ImageIO reads the file at `fileURL` as.
    let contentType: UTType
    /// A small upright copy of the photo for the interface, at most `CameraCapture.thumbnailMaximumPixelSize` on
    /// its long side.
    let thumbnail: CGImage
    /// The output the file was brought to, which a copy with a drawing is brought to as well.
    var output = CameraFlowOutput()

    /// Every file of the photo.
    var fileURLs: [URL] {
        [fileURL, livePhotoMovieURL].compactMap(\.self)
    }
}
