//
//  PhotoFilePreview.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// What the flow needs to know about a photo file: its type, its upright size and a small upright thumbnail made
/// from the image itself, since a thumbnail embedded in a photo edited elsewhere may show an older picture.
struct PhotoFilePreview: Sendable {
    let contentType: UTType
    let uprightSize: CGSize
    let thumbnail: CGImage

    init(url: URL, maximumPixelSize: Int = CameraCapture.thumbnailMaximumPixelSize) throws {
        let photo: ImageSourcePhoto
        do {
            photo = try ImageSourcePhoto(url: url)
        } catch {
            throw CameraServiceError.noImageData
        }
        guard let contentType = photo.type, let thumbnail = photo.uprightImage(maximumLongSide: maximumPixelSize) else {
            throw CameraServiceError.noImageData
        }
        self.contentType = contentType
        uprightSize = Self.uprightSize(of: photo)
        self.thumbnail = thumbnail
    }

    /// Reads the preview off the main actor, since a large photo takes a while to decode.
    @concurrent
    static func read(url: URL, maximumPixelSize: Int) async throws -> Self {
        try Self(url: url, maximumPixelSize: maximumPixelSize)
    }

    /// The upright size of the photo in the bytes, read as the type the hint names first when there is one.
    static func uprightSize(of data: Data, typeHint: UTType? = nil) throws -> CGSize {
        let photo: ImageSourcePhoto
        do {
            photo = try ImageSourcePhoto(data: data, typeHint: typeHint)
        } catch {
            throw CameraServiceError.noImageData
        }
        return uprightSize(of: photo)
    }

    /// The type of the photo in the bytes, read as the type the hint names first when there is one. Bytes have no file
    /// name extension, and a DNG without the hint reads as the TIFF of the preview its first directory holds. A photo
    /// cut short still has its type.
    static func contentType(of data: Data, typeHint: UTType? = nil) throws -> UTType {
        let source: CGImageSource
        do {
            source = try ImageSourcePhoto.source(data: data, typeHint: typeHint)
        } catch {
            throw CameraServiceError.noImageData
        }
        guard let type = ImageSourcePhoto.typeIdentifier(of: source).flatMap({ UTType($0) }) else {
            throw CameraServiceError.noImageData
        }
        return type
    }

    private static func uprightSize(of photo: ImageSourcePhoto) -> CGSize {
        CGSize(width: photo.uprightWidth, height: photo.uprightHeight)
    }
}
