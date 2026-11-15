//
//  OverlayPhotoWriter.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import os
import UniformTypeIdentifiers

/// Draws an overlay stretched over the size it is given into a bitmap in Core Graphics' own coordinates: one unit
/// per pixel, the origin at the bottom left.
typealias OverlayDrawing = (CGContext, CGSize) async throws -> Void

/// Writes a copy of a photo file with an overlay drawn over it: the photo upright, at its full size with the
/// metadata of the original, or as an output asks for it. The photo is decoded once, at the size of the copy, and
/// the copy is encoded once, in its final format at its final quality.
///
/// The copy keeps what a copy without an overlay keeps: every metadata key, the colour profile, the bit depth (a
/// photo of more than 8 bits a component is drawn in 16, which a HEIC holds as 10) and the auxiliary images, turned
/// upright and scaled with the photo: the gain maps (Apple's, and the ISO one from iOS 18), the mattes, depth and
/// disparity. Under the overlay the gain maps are brought to no boost, so an HDR screen shows the overlay as it was
/// drawn and the photo around it as bright as before. The copy has a thumbnail of its own pixels, and the EXIF tags
/// that describe the pixels (their size and the subject area, turned upright with them) describe the copy's. A copy
/// without the metadata has no auxiliary images and no thumbnail either.
///
/// The original is only read. The copy takes the most memory while the photo is decoded into its bitmap, which holds
/// at most `maximumPixelCount` pixels: a larger photo, such as a huge picture from the library, is scaled down to
/// them. The decoded photo is released before the overlay is drawn, the bitmap before the file is encoded, and the
/// encoded file is never held in memory.
enum OverlayPhotoWriter {
    /// The most pixels of a copy: those of a 48 MP photo of the iPhone's camera, 8064 x 6048.
    static let maximumPixelCount = 8064 * 6048

    /// The types that hold auxiliary images.
    private static let auxiliaryImageTypes: [UTType] = [.heic, .jpeg]
    private static let logger = Logger.camera("OverlayPhotoWriter")

    /// Writes the copy into `directory`, which is created when it is missing, and returns where it is. The copy is
    /// named after the photo with `label` and a number, such as `photo-markup-1.heic`.
    ///
    /// The copy is brought to `output`: within its size limit, in its format at its quality, without the metadata
    /// when it strips them. The default output keeps the photo's size, its metadata and its type, a HEIC for a type
    /// ImageIO does not write. A photo of more than `maximumPixelCount` pixels is scaled down to them.
    ///
    /// `drawOverlay` draws the overlay stretched over the size it is given, in Core Graphics' own coordinates: one
    /// unit per pixel, the origin at the bottom left. It draws into the copy's bitmap, with the photo already in it,
    /// and then into a clear bitmap of each size the gain maps of the photo have, to tell how far the overlay covers
    /// them.
    @concurrent
    static func writeCopy(
        of photoURL: URL,
        into directory: URL,
        label: String,
        output: CameraFlowOutput,
        maximumPixelCount: Int = maximumPixelCount,
        drawOverlay: OverlayDrawing
    ) async throws -> URL {
        let original: ImageSourcePhoto
        do {
            original = try ImageSourcePhoto(url: photoURL)
        } catch {
            throw OverlayCopyFailure.unreadablePhoto(photoURL)
        }
        let type = copyType(forPhotoType: original.type, in: output)
        let limit = output.size.maximumLongSide
        let longSide = copyLongSide(of: original, maximumLongSide: limit, maximumPixelCount: maximumPixelCount)
        let copy = try await overlaidImage(
            of: original,
            at: photoURL,
            longSide: longSide,
            type: type,
            drawOverlay: drawOverlay
        )
        let quality = output.format.compressionQuality ?? ImageEncoding.defaultCompressionQuality
        let kept = output.metadata == .stripped
            ? nil
            : try await keptContent(of: original, in: copy, type: type, drawOverlay: drawOverlay)
        let encoding = CopyEncoding(type: type, quality: quality, kept: kept)
        let name = CopyName(photoURL: photoURL, label: label)
        return try store(copy, encoding: encoding, name: name, into: directory)
    }

    /// How a copy is encoded.
    private struct CopyEncoding {
        let type: UTType
        let quality: Double
        /// What the copy keeps of the original, nil for a copy without the metadata.
        let kept: KeptContent?
    }

    /// The metadata and the auxiliary images of the original, for the pixels of the copy.
    private struct KeptContent {
        let metadata: CGImageMetadata
        let originalProperties: [CFString: Any]
        let auxiliaryImages: [(type: CFString, info: [CFString: Any])]
    }

    /// The numbered name of a copy: the photo's name, a label and a number.
    private struct CopyName {
        let photoURL: URL
        let label: String

        func stem(number: Int) -> String {
            "\(photoURL.deletingPathExtension().lastPathComponent)-\(label)-\(number)"
        }
    }

    /// The long side of a copy: the photo's own, or less where the output limits it, or where the copy would have
    /// more pixels than `maximumPixelCount`.
    private static func copyLongSide(
        of original: ImageSourcePhoto,
        maximumLongSide: Int?,
        maximumPixelCount: Int
    ) -> Int {
        let longSide = max(original.pixelWidth, original.pixelHeight)
        let pixelCount = Double(original.pixelWidth) * Double(original.pixelHeight)
        let fittingScale = min((Double(maximumPixelCount) / pixelCount).squareRoot(), 1)
        let fittingLongSide = max(Int((Double(longSide) * fittingScale).rounded(.down)), 1)
        return min(longSide, maximumLongSide ?? longSide, fittingLongSide)
    }

    /// The upright photo with the overlay over it. Its bitmap is gone once it is returned: ImageIO encodes an
    /// image whose bitmap is still alive from a second copy of the pixels.
    private static func overlaidImage(
        of original: ImageSourcePhoto,
        at url: URL,
        longSide: Int,
        type: UTType,
        drawOverlay: OverlayDrawing
    ) async throws -> CGImage {
        let bitmap = try uprightBitmap(of: original, at: url, longSide: longSide, type: type)
        try await drawOverlay(bitmap, CGSize(width: bitmap.width, height: bitmap.height))
        guard let image = bitmap.makeImage() else {
            throw OverlayCopyFailure.cannotCreateBitmap(width: bitmap.width, height: bitmap.height)
        }
        return image
    }

    /// A bitmap with the upright photo in it, with `longSide` pixels on its long side. The clear parts of the photo
    /// stay clear in a copy of a type that holds them. The decoded photo is gone once the bitmap is returned.
    private static func uprightBitmap(
        of original: ImageSourcePhoto,
        at url: URL,
        longSide: Int,
        type: UTType
    ) throws -> CGContext {
        guard let photo = original.uprightImage(maximumLongSide: longSide) else {
            throw OverlayCopyFailure.unreadablePhoto(url)
        }
        let layout = try CopyBitmapLayout(photo: photo, type: type)
        guard let bitmap = CGContext(
            data: nil,
            width: photo.width,
            height: photo.height,
            bitsPerComponent: layout.bitsPerComponent,
            bytesPerRow: 0,
            space: layout.colorSpace,
            bitmapInfo: layout.bitmapInfo
        ) else {
            throw OverlayCopyFailure.cannotCreateBitmap(width: photo.width, height: photo.height)
        }
        let rectangle = CGRect(x: 0, y: 0, width: photo.width, height: photo.height)
        if let background = layout.background {
            bitmap.setFillColor(background)
            bitmap.fill(rectangle)
        }
        bitmap.draw(photo, in: rectangle)
        return bitmap
    }

    /// The metadata and the auxiliary images of the original for the copy. An auxiliary image that cannot be brought
    /// to the copy is logged and left out: a gain map left as it is would boost the overlay.
    private static func keptContent(
        of original: ImageSourcePhoto,
        in copy: CGImage,
        type: UTType,
        drawOverlay: OverlayDrawing
    ) async throws -> KeptContent {
        let scale = Double(copy.width) / Double(original.uprightWidth)
        var auxiliaryImages: [(type: CFString, info: [CFString: Any])] = []
        var coverages = OverlayCoverages()
        let carried = auxiliaryImageTypes.contains(type) ? original.auxiliaryImages : []
        for auxiliary in carried {
            let upright = PhotoAuxiliaryImage.upright(
                auxiliary.info,
                type: auxiliary.type,
                orientation: original.orientation,
                scale: scale
            )
            switch upright {
            case let .failure(reason):
                logger.info("The copy goes without an auxiliary image: \(reason.description, privacy: .public)")
            case let .success(info) where PhotoGainMap.types.contains(auxiliary.type):
                switch PhotoGainMap(type: auxiliary.type, info: info).underOverlay() {
                case let .failure(reason):
                    logger.info("The copy goes without a gain map: \(reason.description, privacy: .public)")
                case let .success(gainMap):
                    let neutralized = try await gainMap.neutralized(under: &coverages, drawingOverlay: drawOverlay)
                    auxiliaryImages.append((neutralized.type, neutralized.info))
                }
            case let .success(info):
                auxiliaryImages.append((auxiliary.type, info))
            }
        }
        let subjectArea = uprightSubjectArea(of: original, scale: scale)
        let pixels = PhotoPixelDescription(width: copy.width, height: copy.height, subjectArea: subjectArea)
        let metadata: CGImageMetadata
        do {
            metadata = try original.metadata(describing: pixels, isUpright: true)
        } catch {
            throw OverlayCopyFailure.cannotEncode(error.description)
        }
        return KeptContent(
            metadata: metadata,
            originalProperties: original.properties,
            auxiliaryImages: auxiliaryImages
        )
    }

    /// The subject area of the original in the upright pixels of the copy, empty for a photo without one. One that
    /// cannot be turned is logged, and the copy goes without it.
    private static func uprightSubjectArea(of original: ImageSourcePhoto, scale: Double) -> [Int] {
        let storedArea = original.subjectArea
        guard !storedArea.isEmpty else { return [] }
        do {
            let uprightArea = try PhotoSubjectArea.upright(
                storedArea,
                orientation: original.orientation,
                storedWidth: original.pixelWidth,
                storedHeight: original.pixelHeight
            )
            return PhotoSubjectArea.scaled(uprightArea, by: scale)
        } catch {
            logger.info("The copy goes without the subject area: \(error.description, privacy: .public)")
            return []
        }
    }

    /// The type of a copy in an output: the format's own, or with the original format the photo's own type for a
    /// JPEG, a HEIC, a PNG and a TIFF and HEIC for every other type: RAW, GIF and WebP among them, and HEIF, which
    /// ImageIO reads and does not write.
    static func copyType(forPhotoType type: UTType?, in output: CameraFlowOutput = CameraFlowOutput()) -> UTType {
        PhotoOutputEncoder(output: output).outputType(forSourceType: type)
    }

    /// Writes the copy under the first free numbered name after the photo's. A taken name is never replaced.
    private static func store(
        _ image: CGImage,
        encoding: CopyEncoding,
        name: CopyName,
        into directory: URL
    ) throws -> URL {
        guard let fileExtension = encoding.type.preferredFilenameExtension else {
            throw OverlayCopyFailure.cannotStore("The type \(encoding.type.identifier) has no file name extension")
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw storeFailure("Cannot create the directory", cause: error)
        }
        // The copy is encoded in a directory of its own, which goes whichever way the encoding ends, with the
        // temporary file a failed encoding leaves beside its file. The copy takes its numbered name once it is whole.
        let scratch = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: false)
        } catch {
            throw storeFailure("Cannot create the directory", cause: error)
        }
        defer { CaptureFileStore.discard(scratch) }
        let unnamedURL = scratch.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
        try encode(image, encoding: encoding, to: unnamedURL)
        guard let kept = encoding.kept else {
            return try giveFreeName(to: unnamedURL, name: name, in: directory)
        }
        let finishedURL = try CopyMetadataRestoration.restoringLostTags(
            of: unnamedURL,
            encodedWith: kept.metadata,
            originalProperties: kept.originalProperties,
            in: scratch
        )
        return try giveFreeName(to: finishedURL, name: name, in: directory)
    }

    /// Encodes the copy at its quality, with a thumbnail of its pixels where it keeps the metadata.
    private static func encode(_ image: CGImage, encoding: CopyEncoding, to url: URL) throws(OverlayCopyFailure) {
        var options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: encoding.quality]
        if encoding.kept != nil {
            options[kCGImageDestinationEmbedThumbnail] = true
        }
        do {
            try ImageEncoding.file(at: url, typeIdentifier: encoding.type.identifier) { destination in
                guard let kept = encoding.kept else {
                    CGImageDestinationAddImage(destination, image, options as CFDictionary)
                    return
                }
                CGImageDestinationAddImageAndMetadata(destination, image, kept.metadata, options as CFDictionary)
                for auxiliary in kept.auxiliaryImages {
                    CGImageDestinationAddAuxiliaryDataInfo(destination, auxiliary.type, auxiliary.info as CFDictionary)
                }
            }
        } catch {
            throw .cannotEncode(error.description)
        }
    }

    /// Moves the encoded file into the directory under the first free numbered name after the photo's.
    private static func giveFreeName(to unnamedURL: URL, name: CopyName, in directory: URL) throws -> URL {
        var number = 1
        while true {
            let stem = name.stem(number: number)
            let copyURL = directory.appendingPathComponent(stem).appendingPathExtension(unnamedURL.pathExtension)
            do {
                try FileManager.default.moveItem(at: unnamedURL, to: copyURL)
                return copyURL
            } catch CocoaError.fileWriteFileExists {
                number += 1
            } catch {
                throw storeFailure("Cannot name the copy", cause: error)
            }
        }
    }

    /// The failure of a write of the copy: the missing room as it is, any other cause in words after what failed.
    /// ImageIO's encoding says no more than that it failed, so a full device makes it `cannotEncode`.
    private static func storeFailure(_ action: String, cause error: any Error) -> OverlayCopyFailure {
        guard !StorageFailure.isOutOfSpace(error) else { return .notEnoughStorage }
        return .cannotStore("\(action): \(error.localizedDescription)")
    }
}

/// How the bitmap of a copy is laid out for its photo and its type.
private struct CopyBitmapLayout {
    /// 16 for a photo of more than 8 bits a component, 8 otherwise.
    let bitsPerComponent: Int
    /// The photo's colour space when it is an RGB one the components fit, and Display P3 otherwise: a
    /// floating-point photo decodes into an extended range.
    let colorSpace: CGColorSpace
    /// Premultiplied for a photo with clear parts in a type that keeps them, opaque otherwise.
    let alphaInfo: CGImageAlphaInfo
    /// Painted before the photo where its clear parts are not kept: white, as ImageIO flattens a photo with clear
    /// parts into a JPEG.
    let background: CGColor?

    init(photo: CGImage, type: UTType) throws {
        bitsPerComponent = photo.bitsPerComponent > 8 ? 16 : 8
        let photoColorSpace = photo.colorSpace.flatMap { colorSpace in
            colorSpace.model == .rgb && CGColorSpaceUsesExtendedRange(colorSpace) == false ? colorSpace : nil
        }
        guard let colorSpace = photoColorSpace ?? CGColorSpace(name: CGColorSpace.displayP3) else {
            throw OverlayCopyFailure.cannotCreateBitmap(width: photo.width, height: photo.height)
        }
        self.colorSpace = colorSpace
        let opaque: [CGImageAlphaInfo] = [.none, .noneSkipFirst, .noneSkipLast]
        let hasClearParts = opaque.contains(photo.alphaInfo) == false
        let keepsClearParts = hasClearParts && type != .jpeg
        alphaInfo = keepsClearParts ? .premultipliedLast : .noneSkipLast
        background = hasClearParts && keepsClearParts == false ? CGColor(gray: 1, alpha: 1) : nil
    }

    var bitmapInfo: UInt32 {
        let byteOrder = bitsPerComponent == 16 ? CGBitmapInfo.byteOrder16Little.rawValue : 0
        return alphaInfo.rawValue | byteOrder
    }
}
