//
//  ImageSourcePhoto.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// An image of a photo file as ImageIO reads it: the file, the index of the image in it, the type ImageIO reads the
/// file as, the properties of the image, the size of its stored pixels and the orientation that turns them upright.
/// The package reads every photo file here, and decodes and takes apart its images here.
struct ImageSourcePhoto {
    /// Why ImageIO cannot read an image of a photo file.
    enum ReadFailure: Error, Equatable {
        /// ImageIO cannot open the file or tell its type: it is no photo file ImageIO knows.
        case unreadableFile
        /// ImageIO knows the type of the file and cannot read the image: its properties, the size of its pixels or
        /// its orientation. A file cut short is such a file.
        case unreadableImage
    }

    let source: CGImageSource
    let index: Int
    /// The type ImageIO reads the file as, whatever its name says, such as `public.heic`.
    let typeIdentifier: String
    /// The properties of the image as ImageIO reads them.
    let properties: [CFString: Any]
    /// The size of the stored pixels, both sides above 0.
    let pixelWidth: Int
    let pixelHeight: Int
    /// The orientation that turns the stored pixels upright: 1 for an image without one, as EXIF reads a photo without
    /// the tag.
    let orientation: CGImagePropertyOrientation

    init(source: CGImageSource, index: Int) throws(ReadFailure) {
        guard let typeIdentifier = Self.typeIdentifier(of: source) else {
            throw .unreadableFile
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0,
              let orientation = Self.orientation(in: properties) else {
            throw .unreadableImage
        }
        self.source = source
        self.index = index
        self.typeIdentifier = typeIdentifier
        self.properties = properties
        pixelWidth = width
        pixelHeight = height
        self.orientation = orientation
    }

    /// The primary image of the file.
    init(primaryImageOf source: CGImageSource) throws(ReadFailure) {
        try self.init(source: source, index: CGImageSourceGetPrimaryImageIndex(source))
    }

    /// The primary image of the file at `url`.
    init(url: URL) throws(ReadFailure) {
        let source = try Self.source(url: url)
        try self.init(primaryImageOf: source)
    }

    /// The primary image of the bytes, read as the type the hint names first when there is one.
    init(data: Data, typeHint: UTType? = nil) throws(ReadFailure) {
        let source = try Self.source(data: data, typeHint: typeHint)
        try self.init(primaryImageOf: source)
    }

    /// The file at `url`. ImageIO types a file by its file name extension, so a DNG reads as its RAW image, not as the
    /// TIFF of the small preview its first directory holds.
    static func source(url: URL) throws(ReadFailure) -> CGImageSource {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw .unreadableFile
        }
        return source
    }

    /// The bytes as a file, read as the type the hint names first when there is one. Bytes have no file name
    /// extension, and a DNG without the hint reads as the TIFF of its preview.
    static func source(data: Data, typeHint: UTType? = nil) throws(ReadFailure) -> CGImageSource {
        let options = typeHint.map { [kCGImageSourceTypeIdentifierHint: $0.identifier] as CFDictionary }
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
            throw .unreadableFile
        }
        return source
    }

    /// The type ImageIO reads the file as, whatever its name says, nil for a file it cannot tell the type of.
    static func typeIdentifier(of source: CGImageSource) -> String? {
        CGImageSourceGetType(source).map { $0 as String }
    }

    /// The type of the file, nil for one that no type of the system declares, such as an AVIF sequence on some
    /// systems.
    var type: UTType? {
        UTType(typeIdentifier)
    }

    /// The orientation the properties give, 1 for properties without one and nil for a value EXIF does not define.
    private static func orientation(in properties: [CFString: Any]) -> CGImagePropertyOrientation? {
        guard let value = properties[kCGImagePropertyOrientation] else { return .up }
        return (value as? UInt32).flatMap(CGImagePropertyOrientation.init(rawValue:))
    }

    // MARK: - Pixels

    var uprightWidth: Int {
        orientation.swapsSides ? pixelHeight : pixelWidth
    }

    var uprightHeight: Int {
        orientation.swapsSides ? pixelWidth : pixelHeight
    }

    /// The image upright, its long side at most `maximumLongSide` pixels, nil when ImageIO cannot decode it. A photo of
    /// more than 8 bits a component decodes with them. `cachesImmediately` decodes the pixels at once, so drawing them
    /// later costs no decoding.
    func uprightImage(maximumLongSide: Int, cachesImmediately: Bool = false) -> CGImage? {
        // ImageIO applies the orientation to a thumbnail only, so the image is asked for as a thumbnail made from the
        // full image, never taken from the one a file may embed.
        var options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumLongSide
        ]
        if cachesImmediately {
            options[kCGImageSourceShouldCacheImmediately] = true
        }
        return CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary)
    }

    /// The stored pixels as they are, nil when ImageIO cannot decode them.
    func storedImage() -> CGImage? {
        CGImageSourceCreateImageAtIndex(source, index, nil)
    }

    // MARK: - Metadata

    /// Why the metadata of an image cannot be brought to the pixels of a copy, in words for the log.
    struct MetadataFailure: Error, Equatable, CustomStringConvertible {
        let description: String
    }

    /// The EXIF dictionary of the image, empty for an image without one.
    var exif: [CFString: Any] {
        properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
    }

    /// The subject area of the EXIF in the stored pixels, empty for an image without one.
    var subjectArea: [Int] {
        exif[kCGImagePropertyExifSubjectArea] as? [Int] ?? []
    }

    /// The metadata of the image (its EXIF, GPS, TIFF and maker tags and its XMP), nil for an image without any.
    var metadata: CGImageMetadata? {
        CGImageSourceCopyMetadataAtIndex(source, index, nil)
    }

    /// A copy of the metadata of the image to change, empty for an image without any. Nil when ImageIO cannot copy it.
    func mutableMetadata() -> CGMutableImageMetadata? {
        guard let metadata else { return CGImageMetadataCreateMutable() }
        return CGImageMetadataCreateMutableCopy(metadata)
    }

    /// The metadata of the image for the pixels of a copy. The EXIF of a photo that has one says of them what `pixels`
    /// says, and loses its subject area where `pixels` gives none. Pixels drawn upright have the orientation 1.
    func metadata(
        describing pixels: PhotoPixelDescription,
        isUpright: Bool
    ) throws(MetadataFailure) -> CGImageMetadata {
        guard let metadata = mutableMetadata() else {
            throw MetadataFailure(description: "The photo metadata cannot be copied")
        }
        if isUpright {
            let tiff = kCGImagePropertyTIFFDictionary
            let orientation = kCGImagePropertyTIFFOrientation
            guard CGImageMetadataSetValueMatchingImageProperty(metadata, tiff, orientation, 1 as CFNumber) else {
                throw MetadataFailure(description: "Cannot set \(orientation) in the photo metadata")
            }
        }
        guard !exif.isEmpty else { return metadata }
        guard PhotoSubjectArea.remove(from: metadata), pixels.write(into: metadata) else {
            throw MetadataFailure(description: "Cannot describe the pixels of the copy in the photo metadata")
        }
        return metadata
    }

    // MARK: - Auxiliary images

    /// The info of the image's auxiliary image of the type, empty for an image without one: its pixels in the frame of
    /// the stored pixels, their description and its own metadata.
    func auxiliaryInfo(of type: CFString) -> [CFString: Any] {
        CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, index, type) as? [CFString: Any] ?? [:]
    }

    /// The auxiliary images of the image, of the types ImageIO knows, gain maps first.
    var auxiliaryImages: [(type: CFString, info: [CFString: Any])] {
        PhotoAuxiliaryImage.types.compactMap { type in
            let info = auxiliaryInfo(of: type)
            return info.isEmpty ? nil : (type, info)
        }
    }

    /// The types of the auxiliary images of the image, gain maps first.
    var auxiliaryTypes: [CFString] {
        PhotoAuxiliaryImage.types.filter { !auxiliaryInfo(of: $0).isEmpty }
    }
}
