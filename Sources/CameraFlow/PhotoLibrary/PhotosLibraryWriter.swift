//
//  PhotosLibraryWriter.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import Foundation
import os
import Photos

/// The system photo library through the Photos framework.
///
/// A photo goes in as one change: the asset from the camera's file (`.photo`, with the Live Photo movie as
/// `.pairedVideo`), and into the album when one is named. An album is found by its title among the user's albums, or
/// created in the same change, so an asset never ends up in the library without its album: an album that takes no
/// photo fails the save before anything is created (`CameraFlowPhotoLibraryError.albumNotWritable`). The asset gets the
/// location of the photo as well (`PHAssetChangeRequest.location`), so Photos shows the place of a photo whose file
/// cannot carry it, such as a RAW photo. The photo and its movie share one neutral original file name, which Photos
/// shows and exports instead of the names of the flow's files.
///
/// A photo with a drawing goes in as that one asset, edited at creation (`PHContentEditingOutput` over the
/// placeholder of the new asset): the original file is the original resource, the photo with the drawing is the
/// rendered content, and the adjustment data names this flow's edit. Photos shows the drawing and lets the user revert
/// to the original. The change creates the asset and its edit alone, so add-only access is enough.
///
/// The rendered content is made before the change (`PhotoLibraryEditFile`), in a directory of the package that a
/// later run cleans up: a photo with a drawing that cannot be rendered fails while nothing has been created. Inside
/// the change the asset gets its edit only once the rendered content is where Photos reads it. When that last copy
/// fails, the original alone is saved and the asset is reported as saved, missing its drawing: it is in the library,
/// and a save tried again would add it twice.
struct PhotosLibraryWriter: PhotoLibraryWriter {
    /// Names the edit of a drawing in the adjustment data of the asset.
    static let adjustmentFormatIdentifier = "com.cameraflow.markup"
    static let adjustmentFormatVersion = "1.0"

    private static let logger = Logger.camera("PhotosLibraryWriter")

    func authorizationStatus(for access: PhotoLibraryAccess) -> PhotoLibraryAuthorization {
        Self.authorization(PHPhotoLibrary.authorizationStatus(for: Self.accessLevel(access)))
    }

    func requestAuthorization(for access: PhotoLibraryAccess) async -> PhotoLibraryAuthorization {
        Self.authorization(await PHPhotoLibrary.requestAuthorization(for: Self.accessLevel(access)))
    }

    /// Encodes the rendered content of a drawing and looks up the album off the main actor before the change.
    @concurrent
    func add(
        _ entry: PhotoLibraryEntry,
        toAlbumNamed albumName: String?
    ) async throws(CameraFlowPhotoLibraryError) -> CameraFlowPhotoLibraryAsset {
        let album = albumName.map { AlbumTarget(name: $0, existing: Self.album(named: $0)) }
        if let existing = album?.existing, !existing.canPerform(.addContent) {
            throw .albumNotWritable
        }
        let editFileURL = try entry.markedUpFileURL.map(Self.editFile)
        defer {
            if let editFileURL {
                CaptureFileStore.discard(editFileURL)
            }
        }
        let result = ChangeResult()
        do {
            try await PHPhotoLibrary.shared().performChanges {
                Self.create(entry, editFileURL: editFileURL, in: album, result: result)
            }
        } catch {
            Self.logger.error("Photos refused the change", cause: error)
            throw CameraFlowPhotoLibraryError(refusedChange: error)
        }
        guard !result.isAlbumRefused else {
            throw .albumNotWritable
        }
        guard let identifier = result.identifier else {
            throw .noAssetCreated
        }
        let isMissingDrawing = editFileURL != nil && !result.isEditAttached
        return CameraFlowPhotoLibraryAsset(localIdentifier: identifier, isMissingDrawing: isMissingDrawing)
    }

    /// The album a photo goes into: its title, and the user's album of that title when there is one.
    private struct AlbumTarget {
        let name: String
        let existing: PHAssetCollection?
    }

    /// Creates the asset of the photo with its resources, its location and its edit, in its album. Called inside a
    /// change. The album is asked first: a change that stops before it creates the asset adds nothing.
    private static func create(
        _ entry: PhotoLibraryEntry,
        editFileURL: URL?,
        in album: AlbumTarget?,
        result: ChangeResult
    ) {
        var collectionRequest: PHAssetCollectionChangeRequest?
        if let album {
            guard let request = albumRequest(for: album.existing, named: album.name) else {
                result.isAlbumRefused = true
                return
            }
            collectionRequest = request
        }
        let fileNames = OriginalFileNames()
        let request = PHAssetCreationRequest.forAsset()
        let photoOptions = fileNames.options(for: entry.photoFileURL)
        request.addResource(with: .photo, fileURL: entry.photoFileURL, options: photoOptions)
        if editFileURL == nil, let movieURL = entry.livePhotoMovieURL {
            request.addResource(with: .pairedVideo, fileURL: movieURL, options: fileNames.options(for: movieURL))
        }
        request.location = entry.location
        guard let placeholder = request.placeholderForCreatedAsset else { return }
        result.identifier = placeholder.localIdentifier
        if let editFileURL {
            result.isEditAttached = addEdit(editFileURL, to: request, placeholder: placeholder)
        }
        // Photos enumerates the assets to add as a Foundation collection.
        collectionRequest?.addAssets(NSOrderedSet(object: placeholder))
    }

    /// The rendered content of the edit of a photo with a drawing, in a file of its own.
    private static func editFile(of markedUpFileURL: URL) throws(CameraFlowPhotoLibraryError) -> URL {
        do {
            let directory = try CaptureFileStore.temporaryEditDirectory()
            return try PhotoLibraryEditFile.write(markedUpFileURL, into: directory)
        } catch let failure as PhotoLibraryEditFailure {
            logger.error("Cannot render the edit of the asset: \(failure.reason, privacy: .public)")
            throw failure.isOutOfSpace ? .notEnoughSpace : .drawingNotWritten
        } catch {
            logger.error("Cannot make the directory of the edits", cause: error)
            throw (error as? CameraServiceError) == .notEnoughStorage ? .notEnoughSpace : .drawingNotWritten
        }
    }

    /// Gives the asset being created its edit: the rendered content, made before the change, and the adjustment
    /// data of this flow, and returns whether the asset has it. Called inside a change. The asset gets the edit only
    /// once the rendered content is where Photos reads it from: otherwise it is created as the original alone.
    private static func addEdit(
        _ editFileURL: URL,
        to request: PHAssetChangeRequest,
        placeholder: PHObjectPlaceholder
    ) -> Bool {
        let output = PHContentEditingOutput(placeholderForCreatedAsset: placeholder)
        do {
            // A copy within a volume shares the blocks of the file, so a nearly full device needs no room for it.
            try FileManager.default.copyItem(at: editFileURL, to: output.renderedContentURL)
        } catch {
            logger.error("The asset is saved without its drawing, Photos did not get it", cause: error)
            return false
        }
        output.adjustmentData = PHAdjustmentData(
            formatIdentifier: adjustmentFormatIdentifier,
            formatVersion: adjustmentFormatVersion,
            data: Data(adjustmentFormatIdentifier.utf8)
        )
        request.contentEditingOutput = output
        return true
    }

    /// The user's album with the title, nil when there is none.
    private static func album(named name: String) -> PHAssetCollection? {
        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        var found: PHAssetCollection?
        albums.enumerateObjects { album, _, stop in
            guard album.localizedTitle == name else { return }
            found = album
            stop.pointee = true
        }
        return found
    }

    /// The change request of the album: of the one found, or of a new one with the name. Called inside a change.
    private static func albumRequest(
        for album: PHAssetCollection?,
        named name: String
    ) -> PHAssetCollectionChangeRequest? {
        guard let album else {
            return PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
        }
        return PHAssetCollectionChangeRequest(for: album)
    }

    private static func accessLevel(_ access: PhotoLibraryAccess) -> PHAccessLevel {
        switch access {
        case .addOnly: .addOnly
        case .readWrite: .readWrite
        }
    }

    private static func authorization(_ status: PHAuthorizationStatus) -> PhotoLibraryAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .limited: .limited
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .denied
        }
    }
}

/// What a change block learned, written inside the block and read after it.
private final class ChangeResult: @unchecked Sendable {
    /// Written once, by the change block, before `performChanges` returns.
    var identifier: String?
    /// Whether the album refused the asset, written by the change block like `identifier`.
    var isAlbumRefused = false
    /// Whether the asset got the edit with the drawing, written by the change block like `identifier`.
    var isEditAttached = false
}

/// The original file names of the resources of one asset: one new name for the photo and its movie, each with the
/// extension of its file.
private struct OriginalFileNames {
    let stem = UUID().uuidString

    func options(for fileURL: URL) -> PHAssetResourceCreationOptions {
        let options = PHAssetResourceCreationOptions()
        options.originalFilename = "\(stem).\(fileURL.pathExtension)"
        return options
    }
}
#endif
