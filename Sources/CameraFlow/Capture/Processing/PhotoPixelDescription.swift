//
//  PhotoPixelDescription.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import ImageIO

/// What the EXIF of a photo file says of its stored pixels: their size and the subject area in them. A copy of other
/// pixels says it of its own.
struct PhotoPixelDescription {
    let width: Int
    let height: Int
    /// The subject area in the pixels, empty for a photo without one.
    let subjectArea: [Int]

    /// The tags in an EXIF dictionary, as ImageIO merges them into the EXIF of an image it encodes.
    var exifTags: [CFString: Any] {
        var tags: [CFString: Any] = [
            kCGImagePropertyExifPixelXDimension: width,
            kCGImagePropertyExifPixelYDimension: height
        ]
        if !subjectArea.isEmpty {
            tags[kCGImagePropertyExifSubjectArea] = subjectArea
        }
        return tags
    }

    /// Writes the tags into the metadata in place of the ones it holds, false when ImageIO cannot set one. An image
    /// encoded with both properties and metadata takes the values of the metadata.
    func write(into metadata: CGMutableImageMetadata) -> Bool {
        let dimensions = [
            (kCGImagePropertyExifPixelXDimension, width),
            (kCGImagePropertyExifPixelYDimension, height)
        ]
        for (key, value) in dimensions {
            let exif = kCGImagePropertyExifDictionary
            guard CGImageMetadataSetValueMatchingImageProperty(metadata, exif, key, value as CFNumber) else {
                return false
            }
        }
        return subjectArea.isEmpty || PhotoSubjectArea.set(subjectArea, in: metadata)
    }
}
