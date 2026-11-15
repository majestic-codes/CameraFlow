//
//  FlowPhoto.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import CoreLocation
import Foundation
import UniformTypeIdentifiers

/// One photo of the set, from the camera or from the photo library.
struct FlowPhoto: Sendable, Identifiable {
    let id: UUID
    let source: CameraFlowPhoto.Source
    /// The original as the output has it: the camera's file or the copy of the library's file.
    let fileURL: URL
    let contentType: UTType
    /// The movie half of a Live Photo, nil for a still photo.
    let livePhotoMovieURL: URL?
    /// A small upright picture of `pictureURL` for the interface.
    let thumbnail: CGImage
    /// The copy with the second camera's circle of a dual capture, as the output has it, nil for any other photo.
    let dualCameraCopy: CameraFlowPhoto.File?
    /// The full picture for the photo library when no other file of the photo is it (see
    /// `CameraCapture.libraryFileURL`), kept until the set ends.
    var libraryFileURL: URL?
    /// The part of the upright photo the viewfinder showed when the file holds more, nil otherwise.
    var framedRegion: CGRect?
    /// What was drawn on the photo, nil while nothing is.
    var drawing: MarkupDrawing?
    /// The output the files were brought to, with the quality chosen when the photo was taken or picked.
    var output = CameraFlowOutput()
    /// Where a camera photo was taken, nil for one taken without a location and for a photo from the library.
    var location: CLLocation?

    var hasDrawing: Bool {
        drawing != nil
    }

    /// The picture the review shows and a drawing goes over: the copy with the circle of a dual capture, the
    /// original otherwise.
    var pictureURL: URL {
        dualCameraCopy?.url ?? fileURL
    }

    /// Every file of the photo.
    var fileURLs: [URL] {
        [fileURL, livePhotoMovieURL, dualCameraCopy?.url, libraryFileURL].compactMap(\.self)
    }

    /// The full picture for the photo library: the camera's photo, or the full copy with the circle of a dual
    /// capture.
    var libraryPhotoURL: URL {
        libraryFileURL ?? dualCameraCopy?.url ?? fileURL
    }

    /// The camera's files as they go into the photo library, with the photo that has the drawing when there is one.
    /// A photo with a drawing goes without its Live Photo movie, which cannot show the drawing.
    func libraryEntry(markedUpFileURL: URL?) -> PhotoLibraryEntry {
        PhotoLibraryEntry(
            photoFileURL: libraryPhotoURL,
            livePhotoMovieURL: markedUpFileURL == nil ? livePhotoMovieURL : nil,
            markedUpFileURL: markedUpFileURL,
            location: location
        )
    }
}

extension FlowPhoto {
    init(capture: CameraCapture) {
        self.init(
            id: capture.id,
            source: .camera,
            fileURL: capture.fileURL,
            contentType: capture.contentType,
            livePhotoMovieURL: capture.livePhotoMovieURL,
            thumbnail: capture.thumbnail,
            dualCameraCopy: capture.dualCameraCopy,
            libraryFileURL: capture.libraryFileURL,
            framedRegion: capture.framedRegion,
            output: capture.output,
            location: capture.location
        )
    }

    init(libraryPhoto: LibraryPhoto) {
        self.init(
            id: libraryPhoto.id,
            source: .photoLibrary,
            fileURL: libraryPhoto.fileURL,
            contentType: libraryPhoto.contentType,
            livePhotoMovieURL: libraryPhoto.livePhotoMovieURL,
            thumbnail: libraryPhoto.thumbnail,
            dualCameraCopy: nil,
            output: libraryPhoto.output
        )
    }
}

/// The copy that was written of a photo with a drawing, over its picture, its type and a small upright picture of
/// it.
struct MarkedUpCopy: Sendable {
    let fileURL: URL
    /// The type the copy was written in, which a photo of a type ImageIO cannot write has as a HEIC.
    let contentType: UTType
    let thumbnail: CGImage
}

extension CameraFlowPhoto {
    /// The photo as the app receives it. Its edited copy is the one with the drawing, which holds the circle of a
    /// dual capture too, or else the copy with the circle.
    init(_ photo: FlowPhoto, markedUpCopy: MarkedUpCopy?, photoLibrarySave: CameraFlowPhotoLibrarySave?) {
        self.init(
            id: photo.id,
            source: photo.source,
            original: File(url: photo.fileURL, contentType: photo.contentType),
            livePhotoMovieURL: photo.livePhotoMovieURL,
            markedUp: markedUpCopy.map { File(url: $0.fileURL, contentType: $0.contentType) } ?? photo.dualCameraCopy,
            thumbnail: markedUpCopy?.thumbnail ?? photo.thumbnail,
            framedRegion: photo.framedRegion,
            photoLibrarySave: photoLibrarySave
        )
    }

    /// Every file of the photo the receiver gets.
    var fileURLs: [URL] {
        [original.url, livePhotoMovieURL, markedUp?.url].compactMap(\.self)
    }
}
