//
//  FakeLibraryPick.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
@testable import CameraFlow

/// A pick that delivers given bytes as a file with a given extension, or has no file to deliver, and the bytes of a
/// Live Photo movie beside it when given. With a gate it delivers only once the gate has opened.
struct FakeLibraryPick: PhotoLibraryPick {
    /// The bytes of the library's file, nil for a pick that cannot be loaded.
    let data: Data?
    let fileExtension: String
    /// The bytes of the movie of a Live Photo, nil for a still photo.
    let movieData: Data?
    let gate: CallGate?

    init(data: Data?, fileExtension: String = "heic", movieData: Data? = nil, gate: CallGate? = nil) {
        self.data = data
        self.fileExtension = fileExtension
        self.movieData = movieData
        self.gate = gate
    }

    func loadFiles() async throws -> LibraryPickFiles {
        await gate?.pass()
        guard let data else {
            throw PhotoLibraryPickError.noImageFile
        }
        let photoURL = try write(data, fileExtension: fileExtension)
        let movieURL = try movieData.map { try write($0, fileExtension: "mov") }
        return LibraryPickFiles(photoURL: photoURL, livePhotoMovieURL: movieURL)
    }

    private func write(_ data: Data, fileExtension: String) throws -> URL {
        let url = TestDirectory.current
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        try data.write(to: url)
        return url
    }
}
