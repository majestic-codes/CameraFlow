//
//  LibraryLivePhotoBundle.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import UniformTypeIdentifiers

/// The bundle the photo library lends a Live Photo pick in: a directory with the photo and its movie.
enum LibraryLivePhotoBundle {
    /// The types the library lends a Live Photo as: the bundle itself, and anything that is a Live Photo.
    static var types: [UTType] {
        [UTType(importedAs: "com.apple.live-photo-bundle"), .livePhoto]
    }

    /// Copies the photo and the movie of the bundle into the package's directories of picks and of movies, where a
    /// later run removes them when a kill leaves them behind. The bundle must hold one photo and one movie, told by
    /// the types of their file name extensions: anything else throws, and nothing is left of the copies.
    static func copyFiles(
        of bundle: URL,
        parent: URL = FileManager.default.temporaryDirectory
    ) throws -> LibraryPickFiles {
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(at: bundle, includingPropertiesForKeys: nil)
        let photos = files.filter { conforms($0, to: .image) }
        let movies = files.filter { conforms($0, to: .movie) }
        guard photos.count == 1, movies.count == 1, let photo = photos.first, let movie = movies.first else {
            throw PhotoLibraryPickError.unreadableLivePhoto(fileNames: files.map(\.lastPathComponent).sorted())
        }
        let photoCopy = try CaptureFileStore.temporaryPickURL(pathExtension: photo.pathExtension, parent: parent)
        try fileManager.copyItem(at: photo, to: photoCopy)
        do {
            let movieCopy = try CaptureFileStore.temporaryMovieURL(parent: parent)
            try fileManager.copyItem(at: movie, to: movieCopy)
            return LibraryPickFiles(photoURL: photoCopy, livePhotoMovieURL: movieCopy)
        } catch {
            CaptureFileStore.discard(photoCopy)
            throw error
        }
    }

    /// Whether the file name extension names a type of the kind. A name without a known extension is neither.
    private static func conforms(_ file: URL, to type: UTType) -> Bool {
        UTType(filenameExtension: file.pathExtension)?.conforms(to: type) == true
    }
}
