//
//  PhotoLibraryEditFile.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import ImageIO

/// Why the rendered content of an edit could not be written, for the log.
struct PhotoLibraryEditFailure: Error, Equatable {
    let reason: String
    /// Whether the device had no room for the file.
    var isOutOfSpace = false
}

/// The photo with a drawing as the photo library takes the rendered content of an edit: a JPEG of its size with
/// everything else its file holds (`PhotoFileCopy`). It is written before the library is asked for anything, so a
/// photo that cannot be rendered fails while nothing has been created yet.
enum PhotoLibraryEditFile {

    /// Writes the photo as a JPEG into a new file of `directory` and returns where it is. The caller deletes the
    /// file once the library has it. The JPEG is written whole or not at all, so nothing is left behind when the
    /// photo cannot be written.
    static func write(_ photoURL: URL, into directory: URL) throws(PhotoLibraryEditFailure) -> URL {
        let source: CGImageSource
        do {
            source = try ImageSourcePhoto.source(url: photoURL)
        } catch {
            throw PhotoLibraryEditFailure(reason: "The photo with the drawing cannot be read")
        }
        guard CGImageSourceGetCount(source) > 0 else {
            throw PhotoLibraryEditFailure(reason: "The photo with the drawing cannot be read")
        }
        let quality = ImageEncoding.defaultCompressionQuality
        let copy = PhotoFileCopy(type: .jpeg, compressionQuality: quality, maximumLongSide: nil)
        let data: Data
        do {
            data = try copy.data(of: source)
        } catch {
            throw PhotoLibraryEditFailure(reason: "The photo with the drawing cannot be written as a JPEG: \(error)")
        }
        let targetURL = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
        do {
            try data.write(to: targetURL, options: .atomic)
        } catch {
            throw PhotoLibraryEditFailure(
                reason: "The JPEG of the photo with the drawing cannot be kept",
                isOutOfSpace: StorageFailure.isOutOfSpace(error)
            )
        }
        return targetURL
    }
}
