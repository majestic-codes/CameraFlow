//
//  PhotoCapturePipeline.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import os
import UniformTypeIdentifiers

/// Turns a photo the camera delivered into a `CameraCapture`: the file in the session's directory, cropped to the
/// aspect ratio where that loses nothing, brought to the output of the flow, with a small upright thumbnail. It runs
/// off the main actor, since a large photo takes a while to decode and encode.
///
/// A 4:3 photo and a RAW photo are written byte for byte as the camera delivered them. A RAW photo has no
/// re-encoding here, so in another ratio it carries the framed region instead, and the output leaves it alone. When
/// processing fails, every file of the capture is deleted. A copy with the circle or a Live Photo movie that cannot be
/// written for any reason but a full disk is left out instead, and the capture says so in `losses`.
///
/// A HEIF or JPEG photo with a location or a direction of the camera gets the GPS dictionary before the crop
/// (`PhotoLocationWriter`), with the image and everything else the camera wrote kept. A RAW photo stays as the camera
/// wrote it, without GPS: ImageIO cannot write a DNG.
///
/// An output that scales, re-encodes or strips the photo (`PhotoOutputEncoder`) makes two files: the output for the
/// app and the camera's photo beside it, for the photo library. A flow that never saves keeps the output alone.
///
/// A dual capture also gets the copy with the circle of the other camera (`DualCameraPhotoWriter`), composited into
/// the camera's photo and encoded once, straight in the output of the photo, and its thumbnail shows that copy. The
/// photo library takes the copy with the circle instead of the camera's photo: a full copy, composited into the
/// camera's photo as well, stays beside the output one when the output changed the photo and the flow saves.
struct PhotoCapturePipeline: Sendable {
    let aspectRatio: CameraFlowAspectRatio
    let output: CameraFlowOutput
    let store: CaptureFileStore
    /// Where the viewfinder shows the circle of the other camera, nil while it shows none.
    var dualCameraCircle: DualCameraCircle?
    /// Where the camera pointed at the shutter release, nil for a photo without the direction.
    var heading: PhotoHeading?
    /// Whether the full picture for the photo library is kept beside an output that changed the photo: false for a
    /// flow that never saves, which has no use for it.
    var keepsLibraryPicture = true

    private static let logger = Logger.camera("PhotoCapturePipeline")

    @concurrent
    func process(_ photo: CapturedPhoto) async throws -> CameraCapture {
        let identifier = UUID()
        var writtenURLs: [URL] = []
        var movieURL = photo.livePhotoMovieURL
        do {
            let delivered = try deliveredFile(of: photo)
            var files = try writeFiles(of: delivered, from: photo, identifier: identifier, written: &writtenURLs)
            var losses: [CapturedPhotoLoss] = []
            if let frame = photo.circleCameraFrame {
                let dual = try await addingDualCameraCopyOrLoss(
                    of: frame,
                    to: files,
                    framedRegion: delivered.framedRegion,
                    identifier: identifier,
                    written: &writtenURLs
                )
                files = dual.files
                losses += [dual.loss].compactMap(\.self)
            }
            if let movieSource = photo.livePhotoMovieURL {
                movieURL = try movedMovieOrLoss(from: movieSource, identifier: identifier, losses: &losses)
            }
            let preview = try PhotoFilePreview(url: files.outputURL)
            var thumbnail = preview.thumbnail
            var dualCameraCopy: CameraFlowPhoto.File?
            if let copyURL = files.dualCameraCopyURL {
                let copyPreview = try PhotoFilePreview(url: copyURL)
                thumbnail = copyPreview.thumbnail
                dualCameraCopy = CameraFlowPhoto.File(url: copyURL, contentType: copyPreview.contentType)
            }
            return CameraCapture(
                id: identifier,
                fileURL: files.outputURL,
                libraryFileURL: files.libraryURL,
                contentType: files.outputType,
                thumbnail: thumbnail,
                livePhotoMovieURL: movieURL,
                framedRegion: delivered.framedRegion,
                dualCameraCopy: dualCameraCopy,
                output: output,
                location: photo.location,
                losses: losses
            )
        } catch {
            (writtenURLs + [movieURL].compactMap(\.self)).forEach(CaptureFileStore.discard)
            throw error
        }
    }

    /// The files with the copy with the circle, or without it and the loss when it cannot be written for any
    /// reason but a full disk: only the files the copy wrote go.
    private func addingDualCameraCopyOrLoss(
        of frame: CircleCameraFrame,
        to files: WrittenFiles,
        framedRegion: CGRect?,
        identifier: UUID,
        written: inout [URL]
    ) async throws -> (files: WrittenFiles, loss: CapturedPhotoLoss?) {
        let writtenBefore = written
        do {
            let updatedFiles = try await addingDualCameraCopy(
                of: frame,
                to: files,
                framedRegion: framedRegion,
                identifier: identifier,
                written: &written
            )
            return (updatedFiles, nil)
        } catch {
            try Self.rethrowIfOutOfStorage(error)
            Self.logger.error("The photo is handed over without the circle", cause: error)
            written.filter { !writtenBefore.contains($0) }.forEach(CaptureFileStore.discard)
            written = writtenBefore
            return (withoutDualCameraCopy(files, written: &written), .circleCameraFrame)
        }
    }

    /// The Live Photo movie moved into the store, or nil and the loss when it cannot be moved for any reason but a
    /// full disk: the movie goes then.
    private func movedMovieOrLoss(
        from source: URL,
        identifier: UUID,
        losses: inout [CapturedPhotoLoss]
    ) throws -> URL? {
        do {
            return try store.moveMovie(from: source, identifier: identifier)
        } catch {
            try Self.rethrowIfOutOfStorage(error)
            Self.logger.error("The photo is handed over without its Live Photo movie", cause: error)
            CaptureFileStore.discard(source)
            losses.append(.livePhotoMovie)
            return nil
        }
    }

    /// Rethrows the missing room, which fails the shot: a part of the photo that cannot be written for any other
    /// reason is left out instead.
    static func rethrowIfOutOfStorage(_ error: any Error) throws {
        if case .notEnoughStorage = error as? CameraServiceError {
            throw error
        }
    }

    /// The files of a dual capture whose copy with the circle failed: the camera's photo written beside a changed
    /// output stays the library's picture where the flow saves, and goes where it never does.
    private func withoutDualCameraCopy(_ files: WrittenFiles, written: inout [URL]) -> WrittenFiles {
        var updatedFiles = files
        updatedFiles.dualCameraCopyURL = nil
        if let cameraURL = files.libraryURL, !keepsLibraryPicture {
            written.removeAll { $0 == cameraURL }
            CaptureFileStore.discard(cameraURL)
            updatedFiles.libraryURL = nil
        }
        return updatedFiles
    }

    private struct DeliveredFile {
        let data: Data
        let framedRegion: CGRect?
        /// The type ImageIO reads the bytes as first, nil to let it tell from the bytes.
        var typeHint: UTType?
    }

    /// The type of a RAW photo. Its bytes alone read as the TIFF of the preview its first directory holds.
    private static let dngType = UTType(importedAs: "com.adobe.raw-image")

    private struct WrittenFiles {
        let outputURL: URL
        let outputType: UTType
        /// The full picture for the photo library when no other file is it.
        var libraryURL: URL?
        var dualCameraCopyURL: URL?
    }

    /// Writes the output file, and the camera's photo beside it when the output changed it and the photo library or
    /// the copy with the circle needs it. A RAW photo is the output as it is.
    private func writeFiles(
        of delivered: DeliveredFile,
        from photo: CapturedPhoto,
        identifier: UUID,
        written: inout [URL]
    ) throws -> WrittenFiles {
        let cameraType = try PhotoFilePreview.contentType(of: delivered.data, typeHint: delivered.typeHint)
        let isRAW = photo.encoding == .appleProRAW
        let encoded = isRAW ? nil : try PhotoOutputEncoder(output: output).encode(delivered.data)
        guard let encoded else {
            let outputURL = try store.writePhoto(delivered.data, identifier: identifier, type: cameraType)
            written.append(outputURL)
            return WrittenFiles(outputURL: outputURL, outputType: cameraType)
        }
        guard keepsLibraryPicture || photo.circleCameraFrame != nil else {
            let outputURL = try store.writePhoto(encoded.data, identifier: identifier, type: encoded.type)
            written.append(outputURL)
            return WrittenFiles(outputURL: outputURL, outputType: encoded.type)
        }
        let cameraURL = try store.writePhoto(delivered.data, identifier: identifier, type: cameraType, mark: "camera")
        written.append(cameraURL)
        let outputURL = try store.writePhoto(encoded.data, identifier: identifier, type: encoded.type)
        written.append(outputURL)
        return WrittenFiles(outputURL: outputURL, outputType: encoded.type, libraryURL: cameraURL)
    }

    /// Composites the circle's frame into the camera's photo, once for every file that has it: at full size with
    /// its metadata, and straight in the output where the output changed the photo, so each copy is encoded once.
    /// The full copy is the library's picture: kept beside the output one, while the camera's photo beside the
    /// output goes. A flow that never saves gets no full copy beside the output one.
    private func addingDualCameraCopy(
        of frame: CircleCameraFrame,
        to files: WrittenFiles,
        framedRegion: CGRect?,
        identifier: UUID,
        written: inout [URL]
    ) async throws -> WrittenFiles {
        guard let dualCameraCircle else {
            throw CameraServiceError.captureFailed("A dual capture came without the place of its circle")
        }
        let composition = DualCameraPhotoWriter.Composition(
            frame: frame,
            circle: dualCameraCircle,
            framedRegion: framedRegion
        )
        var updatedFiles = files
        guard let cameraURL = files.libraryURL else {
            let fullCopyURL = try await DualCameraPhotoWriter.writeCopy(
                of: files.outputURL,
                composition: composition,
                into: store.directory
            )
            written.append(fullCopyURL)
            updatedFiles.dualCameraCopyURL = fullCopyURL
            return updatedFiles
        }
        updatedFiles.libraryURL = nil
        if keepsLibraryPicture {
            let fullCopyURL = try await DualCameraPhotoWriter.writeCopy(
                of: cameraURL,
                composition: composition,
                into: store.directory
            )
            written.append(fullCopyURL)
            updatedFiles.libraryURL = fullCopyURL
        }
        let unnamedCopyURL = try await DualCameraPhotoWriter.writeCopy(
            of: cameraURL,
            composition: composition,
            into: store.directory,
            output: output
        )
        written.append(unnamedCopyURL)
        let label = DualCameraPhotoWriter.copyLabel
        let copyURL = try store.moveCopy(from: unnamedCopyURL, identifier: identifier, mark: label)
        written.removeAll { $0 == unnamedCopyURL }
        written.append(copyURL)
        written.removeAll { $0 == cameraURL }
        CaptureFileStore.discard(cameraURL)
        updatedFiles.dualCameraCopyURL = copyURL
        return updatedFiles
    }

    private func deliveredFile(of photo: CapturedPhoto) throws -> DeliveredFile {
        guard photo.encoding != .appleProRAW else {
            if photo.location != nil || heading != nil {
                Self.logger.info("A RAW photo is handed over without its location and direction")
            }
            let region = try framedRegion(of: photo.imageData, typeHint: Self.dngType)
            return DeliveredFile(data: photo.imageData, framedRegion: region, typeHint: Self.dngType)
        }
        let located = locatedData(of: photo)
        switch try PhotoCaptureCropper.crop(located, to: aspectRatio) {
        case .unchanged:
            return DeliveredFile(data: located, framedRegion: nil)
        case let .cropped(data):
            return DeliveredFile(data: data, framedRegion: nil)
        case let .uncroppable(reason):
            Self.logger.info("The photo is handed over uncropped: \(reason, privacy: .public)")
            return DeliveredFile(data: located, framedRegion: try framedRegion(of: located))
        }
    }

    /// The photo with its location and its direction written in, or the camera's bytes when it has neither or they
    /// cannot be written without a loss.
    private func locatedData(of photo: CapturedPhoto) -> Data {
        let gps = PhotoLocationMetadata.gpsDictionary(location: photo.location, heading: heading)
        guard !gps.isEmpty else { return photo.imageData }
        switch PhotoLocationWriter.addingGPS(gps, to: photo.imageData) {
        case let .located(data):
            return data
        case let .unlocatable(reason):
            Self.logger.info("The photo is handed over without its location", reason: reason)
            return photo.imageData
        }
    }

    /// The centred region of the aspect ratio in unit coordinates of the upright photo, nil when it is all of it.
    private func framedRegion(of data: Data, typeHint: UTType? = nil) throws -> CGRect? {
        guard aspectRatio != .fourByThree else { return nil }
        let size = try PhotoFilePreview.uprightSize(of: data, typeHint: typeHint)
        let width = Int(size.width)
        let height = Int(size.height)
        let rectangle = PhotoCaptureCropper.cropRectangle(width: width, height: height, aspectRatio: aspectRatio)
        if Int(rectangle.width) == width, Int(rectangle.height) == height {
            return nil
        }
        return rectangle.unitRect(in: CGRect(origin: .zero, size: size))
    }
}
