//
//  ImageEncoding.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO

/// Writes photo files with ImageIO: images encoded into the bytes or the file of a type, and a file written again with
/// other metadata, its encoded images and auxiliary images copied as they are. The package writes every photo file
/// here.
enum ImageEncoding {
    /// Why ImageIO cannot write a photo file.
    enum Failure: Error, Equatable, CustomStringConvertible {
        /// There is no buffer for the bytes of the file.
        case noBuffer
        /// ImageIO does not write files of the type.
        case unwritableType(String)
        /// ImageIO cannot finish the file of the type, and does not say why.
        case unfinished(String)
        /// ImageIO cannot write the file of the type again with the metadata, for the reason it gives.
        case uncopied(type: String, reason: String)

        var description: String {
            switch self {
            case .noBuffer: "ImageIO has no buffer to write into"
            case let .unwritableType(type): "ImageIO cannot write \(type)"
            case let .unfinished(type): "ImageIO cannot finish encoding \(type)"
            case let .uncopied(type, reason): "ImageIO cannot write the \(type) again: \(reason)"
            }
        }
    }

    /// The quality of an encoding whose output does not set one: close to the camera's own.
    static let defaultCompressionQuality = 0.9

    /// The bytes of a file of the type, such as `public.heic`, with the images `addImages` adds, `imageCount` of them.
    static func data(
        typeIdentifier: String,
        imageCount: Int = 1,
        addImages: (CGImageDestination) -> Void
    ) throws(Failure) -> Data {
        guard let data = CFDataCreateMutable(nil, 0) else {
            throw .noBuffer
        }
        let type = typeIdentifier as CFString
        guard let destination = CGImageDestinationCreateWithData(data, type, imageCount, nil) else {
            throw .unwritableType(typeIdentifier)
        }
        addImages(destination)
        try finalize(destination, typeIdentifier: typeIdentifier)
        return data as Data
    }

    /// Writes a file of the type at `url` with the image `addImage` adds. ImageIO replaces a file at `url`, and encodes
    /// through a temporary file beside it, which it leaves behind when the encoding fails.
    static func file(
        at url: URL,
        typeIdentifier: String,
        addImage: (CGImageDestination) -> Void
    ) throws(Failure) {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, typeIdentifier as CFString, 1, nil) else {
            throw .unwritableType(typeIdentifier)
        }
        addImage(destination)
        try finalize(destination, typeIdentifier: typeIdentifier)
    }

    /// The bytes of the file of `source` written again as the type with `metadata`, its encoded images and auxiliary
    /// images as they are. With `mergesMetadata` the tags of `metadata` join the file's own, otherwise they replace
    /// them.
    static func data(
        copying source: CGImageSource,
        typeIdentifier: String,
        metadata: CGImageMetadata,
        mergesMetadata: Bool
    ) throws(Failure) -> Data {
        guard let data = CFDataCreateMutable(nil, 0) else {
            throw .noBuffer
        }
        let type = typeIdentifier as CFString
        let imageCount = CGImageSourceGetCount(source)
        guard let destination = CGImageDestinationCreateWithData(data, type, imageCount, nil) else {
            throw .unwritableType(typeIdentifier)
        }
        let copy = CopiedFile(source: source, typeIdentifier: typeIdentifier, metadata: metadata)
        try copy.write(to: destination, mergesMetadata: mergesMetadata)
        return data as Data
    }

    /// Writes the file of `source` again at `url`, as `data(copying:typeIdentifier:metadata:mergesMetadata:)` writes
    /// its bytes.
    static func file(
        at url: URL,
        copying source: CGImageSource,
        typeIdentifier: String,
        metadata: CGImageMetadata,
        mergesMetadata: Bool
    ) throws(Failure) {
        let type = typeIdentifier as CFString
        let imageCount = CGImageSourceGetCount(source)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type, imageCount, nil) else {
            throw .unwritableType(typeIdentifier)
        }
        let copy = CopiedFile(source: source, typeIdentifier: typeIdentifier, metadata: metadata)
        try copy.write(to: destination, mergesMetadata: mergesMetadata)
    }

    private static func finalize(_ destination: CGImageDestination, typeIdentifier: String) throws(Failure) {
        guard CGImageDestinationFinalize(destination) else {
            throw .unfinished(typeIdentifier)
        }
    }

    /// A file written again with other metadata.
    private struct CopiedFile {
        let source: CGImageSource
        let typeIdentifier: String
        let metadata: CGImageMetadata

        /// `CGImageDestinationCopyImageSource` copies the encoded images and every auxiliary image as they are, and
        /// writes the metadata of the file without encoding the pixels again.
        func write(to destination: CGImageDestination, mergesMetadata: Bool) throws(Failure) {
            let options: [CFString: Any] = [
                kCGImageDestinationMetadata: metadata,
                kCGImageDestinationMergeMetadata: mergesMetadata
            ]
            var copyError: Unmanaged<CFError>?
            guard CGImageDestinationCopyImageSource(destination, source, options as CFDictionary, &copyError) else {
                let reason = copyError.map { "\($0.takeRetainedValue())" } ?? "no error given"
                throw .uncopied(type: typeIdentifier, reason: reason)
            }
        }
    }
}
