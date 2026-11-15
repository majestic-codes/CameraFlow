//
//  PhotoSubjectArea.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO

/// The subject area of a photo (EXIF `SubjectArea`) in its stored pixels: a point as its centre, a circle as its
/// centre and diameter, or a rectangle as its centre, width and height.
enum PhotoSubjectArea {
    /// Why a subject area cannot follow a crop or a turn.
    struct Malformed: Error, Equatable, CustomStringConvertible {
        let valueCount: Int

        var description: String {
            "The subject area has \(valueCount) values, not 2, 3 or 4"
        }
    }

    /// The path of the area in XMP.
    private static var path: CFString {
        "\(kCGImageMetadataPrefixExif):SubjectArea" as CFString
    }

    /// The area in a copy of the pixels scaled by `scale`.
    static func scaled(_ values: [Int], by scale: Double) -> [Int] {
        values.map { Int((Double($0) * scale).rounded()) }
    }

    /// The area in the pixels cropped to `rectangle`: the centre moves with the crop and stays inside the cropped
    /// frame, and the size is at most the frame's.
    static func cropped(_ values: [Int], to rectangle: CGRect) throws(Malformed) -> [Int] {
        guard (2...4).contains(values.count) else {
            throw Malformed(valueCount: values.count)
        }
        let width = Int(rectangle.width)
        let height = Int(rectangle.height)
        let centreX = min(max(values[0] - Int(rectangle.minX), 0), width - 1)
        let centreY = min(max(values[1] - Int(rectangle.minY), 0), height - 1)
        return switch values.count {
        case 2: [centreX, centreY]
        case 3: [centreX, centreY, min(values[2], min(width, height))]
        default: [centreX, centreY, min(values[2], width), min(values[3], height)]
        }
    }

    /// The area in the upright pixels of stored pixels of the given size that the orientation turns upright: the centre
    /// moves with the pixel it is on, and the width and the height of a rectangle swap where the sides do.
    static func upright(
        _ values: [Int],
        orientation: CGImagePropertyOrientation,
        storedWidth: Int,
        storedHeight: Int
    ) throws(Malformed) -> [Int] {
        guard (2...4).contains(values.count) else {
            throw Malformed(valueCount: values.count)
        }
        let centre = orientation.uprightPixel(
            column: values[0],
            row: values[1],
            storedWidth: storedWidth,
            storedHeight: storedHeight
        )
        let size = Array(values.dropFirst(2))
        let isTurnedRectangle = size.count == 2 && orientation.swapsSides
        return [centre.column, centre.row] + (isTurnedRectangle ? size.reversed() : size)
    }

    /// Writes the area into the metadata in place of the one it holds. XMP holds the values as text, and a HEIF
    /// written from numbers there loses the tag.
    static func set(_ values: [Int], in metadata: CGMutableImageMetadata) -> Bool {
        let namespace = kCGImageMetadataNamespaceExif
        let prefix = kCGImageMetadataPrefixExif
        let name = "SubjectArea" as CFString
        let elements = values.compactMap { value in
            CGImageMetadataTagCreate(namespace, prefix, name, .string, String(value) as CFString)
        }
        guard elements.count == values.count,
              let tag = CGImageMetadataTagCreate(namespace, prefix, name, .arrayOrdered, elements as CFArray) else {
            return false
        }
        return CGImageMetadataSetTagWithPath(metadata, nil, path, tag)
    }

    /// Takes the area out of the metadata, true when it holds none afterwards.
    static func remove(from metadata: CGMutableImageMetadata) -> Bool {
        guard CGImageMetadataCopyTagWithPath(metadata, nil, path) != nil else { return true }
        return CGImageMetadataRemoveTagWithPath(metadata, nil, path)
    }
}
