//
//  CameraFlowPhoto.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// One photo of a finished set, as files on disk and a small thumbnail.
///
/// A photo the user drew on comes as two pictures: the original as the flow's output has it (``original``), and a
/// copy with the drawing (``markedUp``). So does a photo taken with the second camera's circle: its copy has the
/// circle in it, and a drawing on such a photo goes over the circle, in that same one copy. What the user finished is
/// ``result``: the copy when there is one, the original otherwise. The ``thumbnail`` shows that result. Each file
/// comes with its type (``File``). The receiver keeps whichever files it needs.
///
/// With the default ``CameraFlowOutput`` the original keeps all its metadata, and the flow encodes it again only to
/// crop a 16:9 or 1:1 photo from the sensor's 4:3: ``CameraFlowOutput`` says when it is the camera's file or the
/// library's file byte for byte. Another output scales, re-encodes or strips the file as ``CameraFlowOutput``
/// describes, and the copy with the drawing or the circle with it.
///
/// Ownership: the files of ``original``, ``livePhotoMovieURL`` and ``markedUp`` belong to the receiver from the
/// moment the set is handed over, and they are all the flow leaves: every file it made on the way (the camera's full
/// file kept for the photo library beside a scaled or re-encoded output, the copy with the circle a drawing replaced,
/// the full-size copy rendered for the library) is deleted before the hand-over. Each is a finished file, written to
/// its end. They sit in a temporary directory, which the system may purge, so the receiver moves the files it keeps,
/// such as the file of ``result``, and deletes the rest. Whether a photo reached the system photo library is
/// ``photoLibrarySave``: a copy there is the library's, never one of these files.
///
/// The location of a camera photo (``CameraFlowConfiguration/photoLocation``) is added to the file the camera wrote as
/// its GPS dictionary, which keeps everything else, and goes with every file made from it: the output, the copy with
/// the second camera's circle and the copy with a drawing. While the output keeps the metadata, the Live Photo movie
/// carries it too, as QuickTime metadata (`com.apple.quicktime.location.ISO6709`). A RAW (DNG) photo comes without GPS
/// and with all its other metadata: ImageIO cannot write a DNG, and AVFoundation's metadata replacement drops and
/// corrupts DNG values. So does any photo whose file would lose something with the GPS added. A photo saved to the
/// system photo library gets its location as the asset's own all the same. A photo picked from the library keeps the
/// location of its file, where the system picker hands one over, whatever ``CameraFlowConfiguration/photoLocation``
/// says: only an output that strips the metadata takes it out.
public struct CameraFlowPhoto: Sendable, Hashable, Identifiable {
    /// Where a photo of the set came from.
    ///
    /// A minor release may add cases, so a `switch` over a source needs `@unknown default`.
    @nonexhaustive
    public enum Source: Sendable, Hashable {
        /// Taken with the camera of the flow.
        case camera
        /// Picked from the photo library.
        case photoLibrary
    }

    /// One file of a photo: where it is and of what type.
    public struct File: Sendable, Hashable {
        /// Where the file is.
        public let url: URL
        /// The type of the file, such as `.heic`, `.jpeg` or the DNG type.
        public let contentType: UTType

        /// The file at the URL, of the type.
        /// - Parameters:
        ///   - url: Where the file is.
        ///   - contentType: The type of the file.
        public init(url: URL, contentType: UTType) {
            self.url = url
            self.contentType = contentType
        }
    }

    /// Identifies the photo within the app's lifetime.
    public let id: UUID
    /// Where the photo came from.
    public let source: Source
    /// The original: the camera's file or the library's file as the flow's output has it, such as a HEIC, a JPEG or
    /// a DNG.
    public let original: File
    /// The movie half of a Live Photo, a QuickTime movie, taken with the camera or picked from the library, nil for a
    /// still photo. The movie of a camera photo has no sound: the flow records no audio. A Live Photo picked from the
    /// library comes with its movie as the library has it, unless the output strips the metadata: the movie holds the
    /// place and the camera of the shot, so such a pick comes as its still.
    public let livePhotoMovieURL: URL?
    /// The copy with the drawing, the second camera's circle or both, nil for a photo with neither. Upright, with
    /// the original's metadata, brought to the output as the original is. Its type is the original's, except where
    /// ImageIO cannot write that: a copy of a RAW photo (DNG) or of a picked GIF, WebP or HEIF is a HEIC under an
    /// output of the ``CameraFlowOutputFormat/original`` format.
    ///
    /// The copy keeps the colour profile of the photo and its bit depth, as far as its type holds it: a JPEG is 8-bit.
    /// With the metadata kept it also keeps the auxiliary images, turned upright with the photo: the HDR gain maps,
    /// brought to no boost under the drawing and the circle, the mattes and the depth. It holds at most 48 MP (8064 x
    /// 6048 pixels), so a larger picture from the library is scaled down to that. The copy of a spatial photo is its
    /// left eye.
    public let markedUp: File?
    /// A small upright picture of ``result`` for the interface, so with the drawing when there is one.
    public let thumbnail: CGImage
    /// The part of the upright photo the viewfinder showed, in unit coordinates with the origin at the top left,
    /// when the file holds more than that, and nil when the file is what the viewfinder framed. Set for a 16:9 or 1:1
    /// RAW photo, which is handed over whole in the sensor's 4:3, and for a 16:9 or 1:1 HEIF or JPEG photo that holds
    /// data the crop cannot keep, such as depth.
    public let framedRegion: CGRect?
    /// What became of the photo in the system photo library, nil when the flow did not save it: saving was off when it
    /// counted, or the photo was picked from the library.
    ///
    /// Under ``CameraFlowPhotoLibrarySaving/Moment/whenSetAccepted`` the photo was saved when the set was accepted,
    /// and under ``CameraFlowPhotoLibrarySaving/Moment/afterEachPhoto`` right after the shot, without the drawing,
    /// which ``CameraFlowPhotoLibraryAsset/isMissingDrawing`` then says. A photo with the second camera's circle is
    /// saved as the copy with the circle, at full size with all its metadata, the way the viewfinder showed it. A
    /// photo with a drawing saved when the set was accepted is one asset with the drawing as its edit over the
    /// original, and a Live Photo among those is saved as a still, without its movie.
    public let photoLibrarySave: CameraFlowPhotoLibrarySave?

    /// Creates a photo as the flow hands one over, for an app's own tests and previews: the flow makes the photos of
    /// a set itself. The values are taken as they are, and the files are the app's to provide.
    /// - Parameters:
    ///   - id: Identifies the photo. Default a new identifier.
    ///   - source: Where the photo came from.
    ///   - original: The original file.
    ///   - livePhotoMovieURL: The movie of a Live Photo, nil for a still photo.
    ///   - markedUp: The copy with the drawing or the circle, nil for a photo with neither.
    ///   - thumbnail: A small upright picture of the result.
    ///   - framedRegion: The part of the photo the viewfinder showed, nil when the file is what it framed.
    ///   - photoLibrarySave: What became of the photo in the system photo library, nil when it was not saved.
    public init(
        id: UUID = UUID(),
        source: Source,
        original: File,
        livePhotoMovieURL: URL? = nil,
        markedUp: File? = nil,
        thumbnail: CGImage,
        framedRegion: CGRect? = nil,
        photoLibrarySave: CameraFlowPhotoLibrarySave? = nil
    ) {
        self.id = id
        self.source = source
        self.original = original
        self.livePhotoMovieURL = livePhotoMovieURL
        self.markedUp = markedUp
        self.thumbnail = thumbnail
        self.framedRegion = framedRegion
        self.photoLibrarySave = photoLibrarySave
    }

    /// The picture the user finished: the copy with the drawing or the circle when there is one, the original
    /// otherwise.
    public var result: File {
        markedUp ?? original
    }
}
