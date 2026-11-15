//
//  PhotoLibraryWriter.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation
import Foundation

/// The access a write to the photo library needs.
enum PhotoLibraryAccess: Sendable, Equatable {
    /// Adding photos, nothing else.
    case addOnly
    /// Reading, adding and changing, which albums need.
    case readWrite
}

/// What the user allows the app in the photo library, for one access level.
enum PhotoLibraryAuthorization: Sendable, Equatable {
    /// The user has not been asked yet.
    case notDetermined
    case authorized
    /// Selected photos only. Albums are out of reach.
    case limited
    /// The user said no, now or earlier.
    case denied
    /// A device policy blocks the library and the user cannot change it.
    case restricted
}

/// A camera photo as it goes into the photo library: the camera's own files.
struct PhotoLibraryEntry: Sendable, Equatable {
    /// The photo as the camera took it: full size, with all its metadata. The library keeps it as the original.
    let photoFileURL: URL
    /// The movie half of a Live Photo, paired with the photo in the library. Nil for a still photo, and for a photo
    /// with a drawing, which a movie cannot show.
    let livePhotoMovieURL: URL?
    /// The photo with the user's drawing on it. The library shows it in place of the original and lets the user
    /// revert to the original. Nil for a photo without a drawing.
    let markedUpFileURL: URL?
    /// Where the photo was taken, which the library keeps as the location of the asset. Nil for none.
    var location: CLLocation?
}

/// The system photo library as the flow writes to it.
protocol PhotoLibraryWriter: Sendable {

    func authorizationStatus(for access: PhotoLibraryAccess) -> PhotoLibraryAuthorization
    /// Asks the user for the access and returns the answer. Returns the standing answer when there is one.
    func requestAuthorization(for access: PhotoLibraryAccess) async -> PhotoLibraryAuthorization
    /// Adds the photo to the library, and to the album of that name when one is given, found or created. Returns the
    /// new asset, which misses the drawing of a photo with one when the library did not take it as the edit. The
    /// files are only read.
    func add(
        _ entry: PhotoLibraryEntry,
        toAlbumNamed albumName: String?
    ) async throws(CameraFlowPhotoLibraryError) -> CameraFlowPhotoLibraryAsset
}
