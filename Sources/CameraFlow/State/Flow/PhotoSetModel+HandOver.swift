//
//  PhotoSetModel+HandOver.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// The steps of the hand-over besides the saves: the copies of the photos with a drawing, and the end of a set that
/// reaches nobody.
extension PhotoSetModel {

    /// Writes the copy of every photo with a drawing into the directory of the set, one at a time in the order of
    /// the set, and returns each copy with its thumbnail by its photo. A copy is drawn over the fullest picture the
    /// set still holds of its photo, the camera's own where the output changed it, and encoded once, in the output
    /// its photo was brought to. When a copy fails, the ones written before it are deleted.
    func writeCopies() async throws -> [UUID: MarkedUpCopy] {
        let directory = fileStore.directory
        var copies: [UUID: MarkedUpCopy] = [:]
        for photo in photos {
            guard let drawing = photo.drawing else { continue }
            var copyURL: URL?
            do {
                let url = try await renderer.writeCopy(
                    of: photo.libraryPhotoURL,
                    with: drawing,
                    output: photo.output,
                    into: directory
                )
                copyURL = url
                let preview = try await PhotoFilePreview.read(
                    url: url,
                    maximumPixelSize: CameraCapture.thumbnailMaximumPixelSize
                )
                let copy = MarkedUpCopy(fileURL: url, contentType: preview.contentType, thumbnail: preview.thumbnail)
                copies[photo.id] = copy
            } catch {
                if let copyURL {
                    CaptureFileStore.discard(copyURL)
                }
                copies.values.forEach { CaptureFileStore.discard($0.fileURL) }
                throw error
            }
        }
        return copies
    }

    /// Deletes an accepted set that reaches nobody: every file it would hand over and its directory, before the
    /// directory is given away, so nothing of it is left behind. The observer hears that the flow ended without a set.
    func deleteUnreceived(_ handedOver: [CameraFlowPhoto]) {
        Self.logger.error("An accepted set reached no receiver, so its photos were deleted")
        handedOver.flatMap(\.fileURLs).forEach(CaptureFileStore.discard)
        fileStore.removeDirectoryIfEmpty()
        handOverObserver?.setDeleted()
    }
}
