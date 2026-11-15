//
//  PhotoFileCopy.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import os
import UniformTypeIdentifiers

/// A photo encoded again, in a type and within a limit of its long side, with everything else its file holds: every
/// property dictionary and XMP tag, the orientation tag, the colour profile and the bit depth the type holds, the
/// auxiliary images (gain maps, mattes, depth) and, in a HEIC, both images of a stereo pair with their group. The
/// copy has a thumbnail of its own pixels, and the EXIF tags that describe the pixels (their size and the subject
/// area) describe the copy's.
///
/// ImageIO copies an image from its source (`CGImageDestinationAddImageFromSource`) with every property dictionary,
/// and with the gain maps when it is asked to, scaled with the pixels. It leaves out the other auxiliary images and
/// every XMP tag that no property dictionary holds. A photo with an auxiliary image other than a gain map has every
/// auxiliary image written in: a gain map scaled like the pixels, a matte and depth as they are, since they cover the
/// frame at their own resolution. ImageIO picks the scaled size itself, and picks it differently with auxiliary
/// images written in, so a copy whose EXIF does not give its size, or that lacks an auxiliary image of the photo, is
/// encoded again at the size it got, with every auxiliary image written in. The XMP tags the copy lacks are then
/// merged into it, which writes the metadata again without encoding the pixels. The merge writes the same tags into
/// both images of a stereo pair, since one call writes the metadata of every image.
struct PhotoFileCopy {
    let type: UTType
    let compressionQuality: Double
    /// The most pixels the copy has on its long side, nil for a copy of the photo's size.
    let maximumLongSide: Int?

    private static let logger = Logger.camera("PhotoFileCopy")
    /// The encodings a copy may take: at the planned size, then at the size ImageIO gave it, then once more at the
    /// size ImageIO gave it with every auxiliary image written in.
    private static let maximumEncodingCount = 3

    /// How the images are encoded: their sizes, which their EXIF gives, and whether every auxiliary image is written
    /// in or ImageIO is asked to carry the gain maps.
    private struct Plan {
        let sizes: [PixelSize]
        let writesAuxiliaryImages: Bool
    }

    /// The copy of the primary image of the photo, with the other image of its stereo pair in a HEIC.
    func data(of source: CGImageSource) throws -> Data {
        let primary = try CopiedImage(source: source, index: CGImageSourceGetPrimaryImageIndex(source))
        let images = try copiedImages(of: source, primary: primary)
        let gainMapTypes = PhotoGainMap.types
        var plan = Plan(
            sizes: images.map { scaledSize(of: $0.size) },
            writesAuxiliaryImages: images.contains { image in
                image.auxiliaryTypes.contains { !gainMapTypes.contains($0) }
            }
        )
        for _ in 0..<Self.maximumEncodingCount {
            let copy = try encode(images, of: source, plan: plan)
            let written = try WrittenImages(data: copy)
            let lacksAuxiliaryImage = zip(images, written.auxiliaryTypes).contains { image, types in
                !image.auxiliaryTypes.allSatisfy(types.contains)
            }
            let describesPixels = zip(images, written.describesItsPixels).allSatisfy { image, describes in
                image.photo.exif.isEmpty || describes
            }
            if describesPixels, !lacksAuxiliaryImage {
                return try mergingLostMetadata(into: copy, from: primary.photo)
            }
            plan = Plan(
                sizes: written.sizes,
                writesAuxiliaryImages: plan.writesAuxiliaryImages || lacksAuxiliaryImage
            )
        }
        throw PhotoOutputFailure.cannotEncode("ImageIO gives the copy another size at every encoding")
    }

    /// The size of stored pixels within the limit, the short side scaled with the long one.
    private func scaledSize(of size: PixelSize) -> PixelSize {
        let longSide = max(size.width, size.height)
        guard let maximumLongSide, longSide > maximumLongSide else { return size }
        let scale = Double(maximumLongSide) / Double(longSide)
        return PixelSize(
            width: Int((Double(size.width) * scale).rounded()),
            height: Int((Double(size.height) * scale).rounded())
        )
    }

    // MARK: - The images

    /// One image of the photo as the copy takes it.
    private struct CopiedImage {
        let photo: ImageSourcePhoto
        /// The auxiliary image types it has.
        let auxiliaryTypes: [CFString]
        /// Its entry in the group of a stereo pair, empty for an image outside a pair.
        var group: [CFString: Any] = [:]

        init(source: CGImageSource, index: Int) throws(PhotoOutputFailure) {
            do {
                photo = try ImageSourcePhoto(source: source, index: index)
            } catch {
                throw .unreadablePhoto
            }
            auxiliaryTypes = photo.auxiliaryTypes
        }

        /// The size of its stored pixels in the photo.
        var size: PixelSize {
            PixelSize(width: photo.pixelWidth, height: photo.pixelHeight)
        }
    }

    /// The images the copy holds: the primary image, and in a HEIC both images of the stereo pair it belongs to,
    /// the left one first.
    private func copiedImages(of source: CGImageSource, primary: CopiedImage) throws -> [CopiedImage] {
        guard type == .heic, let pair = try StereoPair.pair(of: source, containing: primary.photo.index) else {
            return [primary]
        }
        var left = try CopiedImage(source: source, index: pair.left)
        left.group = pair.entry(isLeft: true)
        var right = try CopiedImage(source: source, index: pair.right)
        right.group = pair.entry(isLeft: false)
        return [left, right]
    }

    // MARK: - Encoding

    /// The images copied as the plan says. Without the auxiliary images written in, ImageIO is asked to carry the
    /// gain maps. With them, it is not: it would drop its own gain maps from a JPEG as soon as one is written, and
    /// carries only what is written.
    private func encode(_ images: [CopiedImage], of source: CGImageSource, plan: Plan) throws -> Data {
        do {
            return try ImageEncoding.data(typeIdentifier: type.identifier, imageCount: images.count) { destination in
                for (image, size) in zip(images, plan.sizes) {
                    let options = options(for: image, size: size, preservesGainMaps: !plan.writesAuxiliaryImages)
                    let index = image.photo.index
                    CGImageDestinationAddImageFromSource(destination, source, index, options as CFDictionary)
                    if plan.writesAuxiliaryImages {
                        addAuxiliaryImages(of: image, scaledBy: size.scale(from: image.size), to: destination)
                    }
                }
            }
        } catch {
            throw PhotoOutputFailure.cannotEncode(error.description)
        }
    }

    private func options(for image: CopiedImage, size: PixelSize, preservesGainMaps: Bool) -> [CFString: Any] {
        var options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality,
            kCGImageDestinationEmbedThumbnail: true
        ]
        if size != image.size {
            options[kCGImageDestinationImageMaxPixelSize] = max(size.width, size.height)
        }
        if preservesGainMaps {
            options[kCGImageDestinationPreserveGainMap] = true
        }
        if !image.photo.exif.isEmpty {
            let subjectArea = PhotoSubjectArea.scaled(image.photo.subjectArea, by: size.scale(from: image.size))
            let pixels = PhotoPixelDescription(width: size.width, height: size.height, subjectArea: subjectArea)
            // ImageIO merges the tags into the EXIF it copies.
            options[kCGImagePropertyExifDictionary] = pixels.exifTags
        }
        if !image.group.isEmpty {
            options[kCGImagePropertyGroups] = image.group
        }
        return options
    }

    /// Writes every auxiliary image of the image after it: a gain map scaled like the pixels, any other as it is. A
    /// gain map that cannot be scaled is logged, and the copy goes without it.
    private func addAuxiliaryImages(
        of image: CopiedImage,
        scaledBy scale: Double,
        to destination: CGImageDestination
    ) {
        for gainMap in PhotoGainMap.gainMaps(of: image.photo) {
            guard let scaled = gainMap.scaled(by: scale) else {
                Self.logger.info("A gain map of the photo cannot be scaled, and the copy goes without it")
                continue
            }
            CGImageDestinationAddAuxiliaryDataInfo(destination, scaled.type, scaled.info as CFDictionary)
        }
        let gainMapTypes = PhotoGainMap.types
        for type in image.auxiliaryTypes where !gainMapTypes.contains(type) {
            let info = image.photo.auxiliaryInfo(of: type)
            guard !info.isEmpty else { continue }
            CGImageDestinationAddAuxiliaryDataInfo(destination, type, info as CFDictionary)
        }
    }

    // MARK: - The XMP

    /// The copy with the XMP tags of the photo it lacks merged in, as it is when it lacks none. The tags that say
    /// how the photo's pixels are stored (its tiles) stay the copy's own.
    private func mergingLostMetadata(into copy: Data, from photo: ImageSourcePhoto) throws -> Data {
        guard let metadata = photo.metadata else { return copy }
        let written: ImageSourcePhoto
        do {
            written = try ImageSourcePhoto(data: copy)
        } catch {
            throw PhotoOutputFailure.cannotEncode("The copy cannot be read")
        }
        let keptPaths = try Set(ImageMetadataTag.tags(of: written.metadata).map(Self.path))
        let layoutPaths = try Set(Self.layoutTags(of: metadata).map(Self.path))
        let lost = try ImageMetadataTag.tags(of: metadata).filter { tag in
            let path = try Self.path(of: tag)
            return !keptPaths.contains(path) && !layoutPaths.contains(path)
        }
        guard !lost.isEmpty else { return copy }
        let lostMetadata = CGImageMetadataCreateMutable()
        for tag in lost {
            let path = try Self.path(of: tag)
            guard ImageMetadataTag.set(tag, in: lostMetadata) else {
                throw PhotoOutputFailure.cannotEncode("Cannot copy \(path) of the photo metadata")
            }
        }
        do {
            return try ImageEncoding.data(
                copying: written.source,
                typeIdentifier: type.identifier,
                metadata: lostMetadata,
                mergesMetadata: true
            )
        } catch {
            throw PhotoOutputFailure.cannotEncode("Cannot write the metadata of the copy: \(error)")
        }
    }

    /// The tags of the tiles the pixels are stored in.
    private static func layoutTags(of metadata: CGImageMetadata) -> [CGImageMetadataTag] {
        [kCGImagePropertyTIFFTileWidth, kCGImagePropertyTIFFTileLength].compactMap { key in
            CGImageMetadataCopyTagMatchingImageProperty(metadata, kCGImagePropertyTIFFDictionary, key)
        }
    }

    private static func path(of tag: CGImageMetadataTag) throws -> String {
        guard let path = ImageMetadataTag.path(of: tag) else {
            throw PhotoOutputFailure.cannotEncode("A tag of the photo metadata has no name")
        }
        return path
    }
}

/// The size of stored pixels.
private struct PixelSize: Equatable {
    let width: Int
    let height: Int

    /// How much smaller than `size` this size is: the ratio of their long sides.
    func scale(from size: Self) -> Double {
        Double(max(width, height)) / Double(max(size.width, size.height))
    }
}

/// What a copy holds of each of its images: the size, whether its EXIF gives that size (an image without EXIF says
/// nothing else), and the auxiliary image types.
private struct WrittenImages {
    let sizes: [PixelSize]
    let describesItsPixels: [Bool]
    let auxiliaryTypes: [[CFString]]

    init(data: Data) throws(PhotoOutputFailure) {
        let source: CGImageSource
        do {
            source = try ImageSourcePhoto.source(data: data)
        } catch {
            throw .cannotEncode("The copy cannot be read")
        }
        var sizes: [PixelSize] = []
        var describesItsPixels: [Bool] = []
        var auxiliaryTypes: [[CFString]] = []
        for index in 0..<CGImageSourceGetCount(source) {
            let image: ImageSourcePhoto
            do {
                image = try ImageSourcePhoto(source: source, index: index)
            } catch {
                throw .cannotEncode("The size of the copy cannot be read")
            }
            let width = image.pixelWidth
            let height = image.pixelHeight
            sizes.append(PixelSize(width: width, height: height))
            let exif = image.exif
            let describesSize = exif[kCGImagePropertyExifPixelXDimension] as? Int == width
                && exif[kCGImagePropertyExifPixelYDimension] as? Int == height
            describesItsPixels.append(exif.isEmpty || describesSize)
            auxiliaryTypes.append(image.auxiliaryTypes)
        }
        self.sizes = sizes
        self.describesItsPixels = describesItsPixels
        self.auxiliaryTypes = auxiliaryTypes
    }
}

/// The stereo pair group of a photo, as ImageIO reads it from the file.
private struct StereoPair {
    let left: Int
    let right: Int
    /// What both images say of the group: its index and type, and its disparity adjustment where it has one.
    let shared: [CFString: Any]

    private static var sharedKeys: [CFString] {
        [kCGImagePropertyGroupIndex, kCGImagePropertyGroupType, kCGImagePropertyGroupImageDisparityAdjustment]
    }

    /// The pair the image belongs to, nil for an image outside a stereo pair.
    static func pair(of source: CGImageSource, containing index: Int) throws -> Self? {
        let properties = CGImageSourceCopyProperties(source, nil) as? [CFString: Any]
        let groups = properties?[kCGImagePropertyGroups] as? [[CFString: Any]] ?? []
        let stereoType = kCGImagePropertyGroupTypeStereoPair as String
        for group in groups where group[kCGImagePropertyGroupType] as? String == stereoType {
            guard group[kCGImagePropertyGroupIndex] != nil,
                  let left = group[kCGImagePropertyGroupImageIndexLeft] as? Int,
                  let right = group[kCGImagePropertyGroupImageIndexRight] as? Int else {
                throw PhotoOutputFailure.cannotEncode("A stereo pair of the photo does not name its images")
            }
            if index == left || index == right {
                return Self(left: left, right: right, shared: group.filter { sharedKeys.contains($0.key) })
            }
        }
        return nil
    }

    /// The entry of one image of the pair in the group, as an image of a destination takes it.
    func entry(isLeft: Bool) -> [CFString: Any] {
        let side = isLeft ? kCGImagePropertyGroupImageIsLeftImage : kCGImagePropertyGroupImageIsRightImage
        return shared.merging([side: true]) { _, new in new }
    }
}
