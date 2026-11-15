//
//  PhotoOutputEncoder.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Why a photo could not be brought to the output.
enum PhotoOutputFailure: Error, Equatable {
    /// ImageIO cannot read the file.
    case unreadablePhoto
    case cannotEncode(String)
}

/// Brings a photo file to the output the app asked for: scaled to the size limit, in the format, with or without its
/// metadata. A file that meets the output already is left as it is, byte for byte.
///
/// With the metadata kept, the photo is copied with everything its file holds (`PhotoFileCopy`): every property
/// dictionary and XMP tag, the orientation tag, the gain maps, mattes and depth, and in a HEIC both images of a stereo
/// pair. A HEIC keeps a 10-bit photo 10-bit. A JPEG is 8-bit and holds the primary image of a stereo pair only. With
/// the metadata stripped, the pixels are decoded upright and encoded from a bare image, so nothing travels but the
/// pixels, their colour profile and their size.
struct PhotoOutputEncoder: Sendable {
    let output: CameraFlowOutput

    struct Encoded: Equatable {
        let data: Data
        let type: UTType
    }

    /// The types ImageIO writes as they are. A photo of any other type (a DNG, a HEIF, a GIF, a WebP) that the
    /// output touches is encoded as a HEIC.
    private static let writableTypes: [UTType] = [.jpeg, .heic, .png, .tiff]

    /// The output of the photo file at `url`, nil when the file meets the output as it is. The default output leaves
    /// every file alone, readable or not, and unread. ImageIO reads the file by its URL, so the file name extension
    /// types it: a DNG is read as its RAW image, not as the TIFF of the small preview its first directory holds.
    func encode(fileAt url: URL) throws -> Encoded? {
        guard output != CameraFlowOutput() else { return nil }
        let photo: ImageSourcePhoto
        do {
            photo = try ImageSourcePhoto(url: url)
        } catch {
            throw PhotoOutputFailure.unreadablePhoto
        }
        return try encode(photo)
    }

    /// The output of a photo the camera delivered, nil when it meets the output as it is. The default output leaves
    /// every photo alone, readable or not.
    func encode(_ data: Data) throws -> Encoded? {
        guard output != CameraFlowOutput() else { return nil }
        let photo: ImageSourcePhoto
        do {
            photo = try ImageSourcePhoto(data: data)
        } catch {
            throw PhotoOutputFailure.unreadablePhoto
        }
        return try encode(photo)
    }

    private func encode(_ photo: ImageSourcePhoto) throws -> Encoded? {
        let isScaled = exceedsSizeLimit(photo)
        guard isScaled || output.format != .original || output.metadata == .stripped else {
            return nil
        }
        let type = outputType(forSourceType: photo.type)
        let data = switch output.metadata {
        case .kept:
            try PhotoFileCopy(
                type: type,
                compressionQuality: compressionQuality,
                maximumLongSide: isScaled ? output.size.maximumLongSide : nil
            ).data(of: photo.source)
        case .stripped:
            try encodeBarePixels(of: photo, as: type)
        }
        return Encoded(data: data, type: type)
    }

    /// The type of the output of a photo of a type: the format's own, or the photo's where ImageIO writes it.
    func outputType(forSourceType sourceType: UTType?) -> UTType {
        switch output.format {
        case .jpeg: .jpeg
        case .heic: .heic
        case .original: sourceType.flatMap { Self.writableTypes.contains($0) ? $0 : nil } ?? .heic
        }
    }

    private func exceedsSizeLimit(_ photo: ImageSourcePhoto) -> Bool {
        guard let maximum = output.size.maximumLongSide else { return false }
        return max(photo.pixelWidth, photo.pixelHeight) > maximum
    }

    /// The quality of the encoding: the format's own, or close to the camera's for a scaled original.
    private var compressionQuality: Double {
        output.format.compressionQuality ?? ImageEncoding.defaultCompressionQuality
    }

    /// The upright pixels within the limit, encoded from a bare image.
    private func encodeBarePixels(of photo: ImageSourcePhoto, as type: UTType) throws -> Data {
        let longSide = min(max(photo.pixelWidth, photo.pixelHeight), output.size.maximumLongSide ?? .max)
        guard let image = photo.uprightImage(maximumLongSide: longSide) else {
            throw PhotoOutputFailure.cannotEncode("The photo cannot be decoded")
        }
        let imageOptions = [kCGImageDestinationLossyCompressionQuality: compressionQuality]
        do {
            return try ImageEncoding.data(typeIdentifier: type.identifier) { destination in
                CGImageDestinationAddImage(destination, image, imageOptions as CFDictionary)
            }
        } catch {
            throw PhotoOutputFailure.cannotEncode(error.description)
        }
    }
}
