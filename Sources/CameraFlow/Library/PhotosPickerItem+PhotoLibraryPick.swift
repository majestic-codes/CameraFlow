//
//  PhotosPickerItem+PhotoLibraryPick.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import CoreTransferable
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// An item of the system photo picker is a pick: it loads the files the library holds, with all their metadata, the
/// movie of a Live Photo among them.
extension PhotosPickerItem: PhotoLibraryPick {

    func loadFiles() async throws -> LibraryPickFiles {
        let livePhotoTypes = LibraryLivePhotoBundle.types
        let isLivePhoto = supportedContentTypes.contains { type in
            livePhotoTypes.contains { type.conforms(to: $0) }
        }
        if isLivePhoto {
            guard let livePhoto = try await loadTransferable(type: LibraryLivePhotoFiles.self) else {
                throw PhotoLibraryPickError.noImageFile
            }
            return livePhoto.files
        }
        guard let file = try await loadTransferable(type: LibraryImageFile.self) else {
            throw PhotoLibraryPickError.noImageFile
        }
        return LibraryPickFiles(photoURL: file.url, livePhotoMovieURL: nil)
    }
}

/// The files of a Live Photo pick. The library lends the photo and its movie as one bundle for the length of the
/// transfer, so both are copied there and then into the package's directories (`LibraryLivePhotoBundle`).
private struct LibraryLivePhotoFiles: Transferable {
    let files: LibraryPickFiles

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: UTType(importedAs: "com.apple.live-photo-bundle")) { received in
            Self(files: try LibraryLivePhotoBundle.copyFiles(of: received.file))
        }
        FileRepresentation(importedContentType: .livePhoto) { received in
            Self(files: try LibraryLivePhotoBundle.copyFiles(of: received.file))
        }
    }
}

/// The image file of a pick. The library lends its file only for the length of the transfer, so the file is
/// copied there and then into the package's directory of picks, which a later run cleans up when a kill leaves the
/// copy behind.
private struct LibraryImageFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let copy = try CaptureFileStore.temporaryPickURL(pathExtension: received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}
#endif
