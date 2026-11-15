//
//  MetadataExpectations.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import ImageIO
import Testing
@testable import CameraFlow

/// Whether a copy of a photo kept the metadata of the original, key by key and tag by tag.
enum MetadataExpectations {
    /// The keys that describe the pixels, which a copy of other pixels has of its own.
    static let pixelKeys: Set<String> = ["PixelXDimension", "PixelYDimension", "SubjectArea", "TileWidth", "TileLength"]
    /// The keys that describe the pixels of a copy drawn upright: those of `pixelKeys`, and the orientation, 1.
    static let uprightPixelKeys = pixelKeys.union(["Orientation"])

    private static var dictionaryNames: [CFString] {
        [
            kCGImagePropertyExifDictionary,
            kCGImagePropertyTIFFDictionary,
            kCGImagePropertyGPSDictionary,
            kCGImagePropertyMakerAppleDictionary,
            kCGImagePropertyExifAuxDictionary,
            kCGImagePropertyIPTCDictionary
        ]
    }

    /// Records an issue for every key of a property dictionary of the original that the copy lacks or holds with
    /// another value, for every XMP tag of the original the copy lacks, and for another colour profile. The keys
    /// in `changing` may differ or be gone.
    static func expectKept(
        from original: Data,
        in copy: Data,
        changing: Set<String> = pixelKeys,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let originalProperties = try DevicePhotoFixture.properties(of: original)
        let copyProperties = try DevicePhotoFixture.properties(of: copy)
        for name in dictionaryNames {
            guard let originalDictionary = originalProperties[name] as? [String: Any] else { continue }
            let copyDictionary = copyProperties[name] as? [String: Any] ?? [:]
            for (key, value) in originalDictionary where !changing.contains(key) {
                guard let copyValue = copyDictionary[key] else {
                    Issue.record("The copy lost \(name).\(key)", sourceLocation: sourceLocation)
                    continue
                }
                if !isEqual(value, copyValue) {
                    let change = "\(name).\(key): \(value) to \(copyValue)"
                    Issue.record("The copy changed \(change)", sourceLocation: sourceLocation)
                }
            }
        }
        let originalProfile = originalProperties[kCGImagePropertyProfileName] as? String
        let copyProfile = copyProperties[kCGImagePropertyProfileName] as? String
        #expect(copyProfile == originalProfile, sourceLocation: sourceLocation)
        let copyPaths = try xmpPaths(of: copy)
        for path in try xmpPaths(of: original).subtracting(copyPaths) {
            let name = String(path.drop { $0 != ":" }.dropFirst())
            guard !changing.contains(name) else { continue }
            Issue.record("The copy lost the XMP tag \(path)", sourceLocation: sourceLocation)
        }
    }

    /// The value of an XMP tag of the primary image, nil when the photo has none.
    static func xmpValue(at path: String, of data: Data) throws -> String? {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let index = CGImageSourceGetPrimaryImageIndex(source)
        let metadata = CGImageSourceCopyMetadataAtIndex(source, index, nil)
        return metadata.flatMap { CGImageMetadataCopyStringValueWithPath($0, nil, path as CFString) as String? }
    }

    private static func xmpPaths(of data: Data) throws -> Set<String> {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let index = CGImageSourceGetPrimaryImageIndex(source)
        guard let metadata = CGImageSourceCopyMetadataAtIndex(source, index, nil),
              let tags = CGImageMetadataCopyTags(metadata) as? [CGImageMetadataTag] else {
            return []
        }
        return Set(try tags.map { tag in
            let prefix = try #require(CGImageMetadataTagCopyPrefix(tag))
            let name = try #require(CGImageMetadataTagCopyName(tag))
            return "\(prefix):\(name)"
        })
    }

    /// Equal values, numbers within the tolerance of a rational ImageIO writes again.
    private static func isEqual(_ original: Any, _ copy: Any) -> Bool {
        switch (original, copy) {
        case let (original as [String: Any], copy as [String: Any]):
            original.allSatisfy { key, value in copy[key].map { isEqual(value, $0) } ?? false }
        case let (original as [Any], copy as [Any]):
            original.count == copy.count && zip(original, copy).allSatisfy(isEqual)
        case let (original as Double, copy as Double):
            isClose(original, to: copy, tolerance: PhotoMetadataLoss.numberTolerance * max(abs(original), abs(copy), 1))
        case let (original as String, copy as String):
            original == copy
        default:
            String(describing: original) == String(describing: copy)
        }
    }
}
