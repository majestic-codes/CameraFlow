//
//  PhotoLibraryPick.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// One photo the user picked in the photo library, before its files are loaded.
protocol PhotoLibraryPick: Sendable {

    /// Copies the library's files, byte for byte, into new files in the package's folder of the temporary directory,
    /// where a later run removes them when a kill leaves them behind, and returns them: the photo, and the movie of
    /// a Live Photo. Each copy keeps the file name extension of the library's file and belongs to the caller.
    func loadFiles() async throws -> LibraryPickFiles
}

/// The files of a pick, copied from the library.
struct LibraryPickFiles: Sendable, Equatable {
    let photoURL: URL
    /// The movie half of a Live Photo, nil for a still photo.
    let livePhotoMovieURL: URL?

    /// Every file of the pick.
    var fileURLs: [URL] {
        [photoURL, livePhotoMovieURL].compactMap(\.self)
    }
}

enum PhotoLibraryPickError: Error, Equatable {
    /// The library has no image file for the pick.
    case noImageFile
    /// The library's Live Photo does not hold one photo and one movie, by the types of the files it lent.
    case unreadableLivePhoto(fileNames: [String])
}
