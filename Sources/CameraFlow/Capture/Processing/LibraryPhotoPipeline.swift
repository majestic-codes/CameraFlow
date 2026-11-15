//
//  LibraryPhotoPipeline.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// Turns a pick from the photo library into a `LibraryPhoto`: the library's file, byte for byte or brought to the
/// output of the flow, in the directory of the flow, with a small upright thumbnail. It runs off the main actor,
/// since a file from iCloud takes a while to arrive and a large photo a while to decode.
///
/// The movie of a Live Photo goes beside its photo as the library has it, while the output keeps the metadata. An
/// output that strips the metadata leaves the movie out: it holds the place and the camera of the shot, and the
/// photo without its maker notes no longer pairs with it.
///
/// When the file is not a photo ImageIO can read, or anything else fails, nothing of the pick is left on disk.
struct LibraryPhotoPipeline: Sendable {
    let store: CaptureFileStore
    let output: CameraFlowOutput

    @concurrent
    func process(_ pick: any PhotoLibraryPick) async throws -> LibraryPhoto {
        let identifier = UUID()
        let loaded = try await pick.loadFiles()
        // The files of the pick on disk, which a failure deletes.
        var files = loaded.fileURLs
        do {
            let photoURL = try storedFile(from: loaded.photoURL, identifier: identifier)
            files = [photoURL] + [loaded.livePhotoMovieURL].compactMap(\.self)
            let movieURL = try storedMovie(from: loaded.livePhotoMovieURL, identifier: identifier)
            files = [photoURL, movieURL].compactMap(\.self)
            let preview = try PhotoFilePreview(url: photoURL)
            return LibraryPhoto(
                id: identifier,
                fileURL: photoURL,
                livePhotoMovieURL: movieURL,
                contentType: preview.contentType,
                thumbnail: preview.thumbnail,
                output: output
            )
        } catch {
            files.forEach(CaptureFileStore.discard)
            throw error
        }
    }

    /// The movie of a Live Photo moved into the store beside its photo, nil for a still photo and for an output
    /// that strips the metadata, which deletes the movie.
    private func storedMovie(from loadedURL: URL?, identifier: UUID) throws -> URL? {
        guard let loadedURL else { return nil }
        guard output.metadata == .kept else {
            CaptureFileStore.discard(loadedURL)
            return nil
        }
        return try store.moveMovie(from: loadedURL, identifier: identifier)
    }

    /// The loaded file moved into the store as it is, or its output written there and the loaded file gone. ImageIO
    /// reads the loaded file in place, so a file the output leaves alone is moved without being read.
    private func storedFile(from loadedURL: URL, identifier: UUID) throws -> URL {
        guard let encoded = try PhotoOutputEncoder(output: output).encode(fileAt: loadedURL) else {
            return try store.moveLibraryPhoto(from: loadedURL, identifier: identifier)
        }
        let photoURL = try store.writePhoto(encoded.data, identifier: identifier, type: encoded.type)
        CaptureFileStore.discard(loadedURL)
        return photoURL
    }
}
