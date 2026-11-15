//
//  CopyMetadataRestoration.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import ImageIO
import os

/// Puts back the EXIF and TIFF tags of a photo that ImageIO left out of a copy encoded with them, without encoding
/// the image again. ImageIO's JPEG encoder writes the colour space tag it works out from the bitmap and drops the
/// photo's own: a JPEG drawn from a Display P3 photo loses its 65535, uncalibrated.
///
/// A lost tag is taken as it is from the metadata the copy was encoded with, so a rational value keeps its fraction.
/// `CGImageDestinationCopyImageSource` copies the encoded image and every auxiliary image as they are, and writes the
/// copy's complete metadata with the lost tags added to it.
enum CopyMetadataRestoration {
    /// A tag of the photo that a copy lacks: its dictionary and its key, as ImageIO's properties name them.
    struct LostTag: Equatable {
        let dictionary: String
        let key: String
    }

    /// The dictionaries checked, each with the keys a copy writes for its own pixels: their size and subject area, the
    /// orientation of upright pixels, and the tiles of the encoding.
    private static var checkedDictionaries: [(name: CFString, ownKeys: Set<String>)] {
        [
            (
                kCGImagePropertyExifDictionary,
                [
                    kCGImagePropertyExifPixelXDimension as String,
                    kCGImagePropertyExifPixelYDimension as String,
                    kCGImagePropertyExifSubjectArea as String
                ]
            ),
            (
                kCGImagePropertyTIFFDictionary,
                [
                    kCGImagePropertyTIFFOrientation as String,
                    kCGImagePropertyTIFFTileWidth as String,
                    kCGImagePropertyTIFFTileLength as String
                ]
            )
        ]
    }

    private static let logger = Logger.camera("CopyMetadataRestoration")

    /// The tags of the photo's EXIF and TIFF dictionaries that the copy's lack, besides the ones a copy writes for
    /// its own pixels.
    static func lostTags(original: [CFString: Any], copy: [CFString: Any]) -> [LostTag] {
        checkedDictionaries.flatMap { dictionary, ownKeys in
            guard let originalTags = original[dictionary] as? [String: Any] else { return [LostTag]() }
            let copyTags = copy[dictionary] as? [String: Any]
            return originalTags.keys
                .filter { key in copyTags?[key] == nil && ownKeys.contains(key) == false }
                .sorted()
                .map { key in LostTag(dictionary: dictionary as String, key: key) }
        }
    }

    /// The copy at `copyURL` when it lost none of the photo's tags, or else the copy written again into `directory`
    /// with every lost tag of `metadata`, the metadata it was encoded with, and where it is. A tag the metadata does
    /// not hold or ImageIO cannot write is logged and left out.
    static func restoringLostTags(
        of copyURL: URL,
        encodedWith metadata: CGImageMetadata,
        originalProperties: [CFString: Any],
        in directory: URL
    ) throws(OverlayCopyFailure) -> URL {
        let copy: ImageSourcePhoto
        do throws(ImageSourcePhoto.ReadFailure) {
            copy = try ImageSourcePhoto(url: copyURL)
        } catch {
            throw switch error {
            case .unreadableFile: .cannotEncode("The copy cannot be read back")
            case .unreadableImage: .cannotEncode("The copy has no readable properties")
            }
        }
        let lost = lostTags(original: originalProperties, copy: copy.properties)
        guard lost.isEmpty == false else { return copyURL }
        guard let copyMetadata = copy.mutableMetadata() else {
            throw .cannotEncode("The metadata of the copy cannot be copied")
        }
        for tag in lost {
            let isSet = set(tag, from: metadata, in: copyMetadata)
            if isSet == false {
                logger.info("The copy goes without \(tag.key, privacy: .public), which ImageIO cannot write back")
            }
        }
        let restoredName = UUID().uuidString
        let restoredURL = directory.appendingPathComponent(restoredName).appendingPathExtension(copyURL.pathExtension)
        do {
            try ImageEncoding.file(
                at: restoredURL,
                copying: copy.source,
                typeIdentifier: copy.typeIdentifier,
                metadata: copyMetadata,
                mergesMetadata: false
            )
        } catch {
            throw .cannotEncode("Cannot write the copy again with the tags it lost: \(error)")
        }
        return restoredURL
    }

    /// Sets the tag of `metadata` that holds a lost tag into the copy's metadata, false when there is none to set.
    private static func set(
        _ lostTag: LostTag,
        from metadata: CGImageMetadata,
        in copyMetadata: CGMutableImageMetadata
    ) -> Bool {
        let dictionary = lostTag.dictionary as CFString
        let key = lostTag.key as CFString
        guard let tag = CGImageMetadataCopyTagMatchingImageProperty(metadata, dictionary, key) else {
            return false
        }
        return ImageMetadataTag.set(tag, in: copyMetadata)
    }
}
