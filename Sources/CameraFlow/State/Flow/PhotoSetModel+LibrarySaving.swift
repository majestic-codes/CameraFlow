//
//  PhotoSetModel+LibrarySaving.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 13.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// A camera photo saved at a check mark: what became of it, and the drawing it was saved with.
struct AcceptedSave {
    let save: CameraFlowPhotoLibrarySave
    /// The drawing of the photo when it was saved, nil for a photo saved without one.
    let drawing: MarkupDrawing?
}

/// The saves of the hand-over: the camera photos saved when the set is accepted, or the saves after each shot
/// waited for.
extension PhotoSetModel {

    /// Saves the camera photos of the set to the photo library while saving is on, one at a time in the order of the
    /// set, and returns what became of each by its photo. Photos from the library are never saved. A photo the
    /// library took at an earlier check mark is not saved again, and a photo not saved now keeps what an earlier
    /// check mark made of it. Where the photos were saved right after their shot, it waits for the saves still
    /// running instead, and saves nothing again. The asset of a photo saved before its drawing, or before its drawing
    /// changed, misses the drawing the photo is handed over with.
    func saveToLibrary(copies: [UUID: MarkedUpCopy]) async -> [UUID: CameraFlowPhotoLibrarySave] {
        guard let librarySaving else { return [:] }
        var saves: [UUID: CameraFlowPhotoLibrarySave] = [:]
        switch librarySaving.moment {
        case .whenSetAccepted:
            let isSaving = librarySaving.isOn
            for photo in photos where photo.source == .camera {
                if isSaving, !isSavedAtCheckMark(photo.id) {
                    let save = await save(photo, markedUpCopy: copies[photo.id], to: librarySaving)
                    acceptedSaves[photo.id] = AcceptedSave(save: save, drawing: photo.drawing)
                }
                if let accepted = acceptedSaves[photo.id] {
                    saves[photo.id] = accepted.save.handedOver(with: photo.drawing, savedWith: accepted.drawing)
                }
            }
        case .afterEachPhoto:
            for photo in photos {
                let save = await shutterSaves.result(of: photo.id)
                saves[photo.id] = save?.handedOver(with: photo.drawing, savedWith: nil)
            }
        }
        return saves
    }

    /// Whether the photo library took the photo at a check mark that left the set open.
    func isSavedAtCheckMark(_ photoIdentifier: UUID) -> Bool {
        guard case .saved = acceptedSaves[photoIdentifier]?.save else { return false }
        return true
    }

    /// Saves the photo as the camera took it. A drawing goes with it as the edit of the same asset, over the
    /// library's own picture: when the output changed the file the set holds, the drawing is rendered again at the
    /// full size of the original.
    private func save(
        _ photo: FlowPhoto,
        markedUpCopy: MarkedUpCopy?,
        to librarySaving: PhotoLibrarySavingModel
    ) async -> CameraFlowPhotoLibrarySave {
        var markedUpURL = markedUpCopy?.fileURL
        var fullSizeCopyURL: URL?
        if let drawing = photo.drawing, photo.libraryFileURL != nil {
            do {
                let directory = fileStore.directory
                let url = try await renderer.writeCopy(
                    of: photo.libraryPhotoURL,
                    with: drawing,
                    output: CameraFlowOutput(),
                    into: directory
                )
                fullSizeCopyURL = url
                markedUpURL = url
            } catch {
                Self.logger.error("Cannot write the copy for the photo library", cause: error)
                let isOutOfSpace = (error as? MarkupFailure) == .notEnoughStorage
                return .failed(.libraryError(isOutOfSpace ? .notEnoughSpace : .drawingNotWritten))
            }
        }
        defer {
            if let fullSizeCopyURL {
                CaptureFileStore.discard(fullSizeCopyURL)
            }
        }
        return await librarySaving.save(photo.libraryEntry(markedUpFileURL: markedUpURL))
    }
}

private extension CameraFlowPhotoLibrarySave {

    /// What became of a photo saved with one drawing as it is handed over with another: its asset misses the drawing
    /// handed over unless the photo was saved with that drawing and Photos took it.
    func handedOver(with drawing: MarkupDrawing?, savedWith savedDrawing: MarkupDrawing?) -> Self {
        guard case let .saved(asset) = self else { return self }
        let handedOver = CameraFlowPhotoLibraryAsset(
            localIdentifier: asset.localIdentifier,
            isMissingDrawing: drawing != nil && (drawing != savedDrawing || asset.isMissingDrawing)
        )
        return .saved(handedOver)
    }
}
