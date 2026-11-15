//
//  PhotoMetadataLoss.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import ImageIO

/// What a photo file written again lost against its source: an image, a property or a value of one, or the bytes
/// of an auxiliary image. A written file may gain properties, never lose or change one. The values of the photo a
/// loss names are the details of its reason.
enum PhotoMetadataLoss {
    /// A value the written file does not keep.
    struct Difference: Equatable {
        /// Where the value lies, such as `{Exif}.FNumber`, with ` (removed)` after a key the written file lacks.
        let path: String
        /// The number the value was and the number it became, such as `1.78 to 2.8`, empty for any other value.
        var values = ""
    }

    /// The largest relative difference of a number written again: ImageIO stores a rational EXIF value such as
    /// the focal length as a fraction of its own choosing, which moves it in the tenth significant digit.
    static let numberTolerance = 1e-8

    /// What the written file lost against the photo, nil when it kept everything. The properties named in `ignoring`
    /// are not compared.
    static func loss(
        from original: ImageSourcePhoto,
        to data: Data,
        ignoring ignoredKeys: Set<String> = []
    ) -> LoggedReason? {
        let written: ImageSourcePhoto
        do throws(ImageSourcePhoto.ReadFailure) {
            let writtenSource = try ImageSourcePhoto.source(data: data)
            guard CGImageSourceGetCount(writtenSource) == CGImageSourceGetCount(original.source) else {
                return LoggedReason("The written photo has another image count")
            }
            written = try ImageSourcePhoto(primaryImageOf: writtenSource)
        } catch {
            return switch error {
            case .unreadableFile: LoggedReason("The written photo has another image count")
            case .unreadableImage: LoggedReason("The written photo has no readable properties")
            }
        }
        for (key, value) in original.properties where !ignoredKeys.contains(key as String) {
            guard let writtenValue = written.properties[key] else {
                return LoggedReason("The written photo lost \(key)")
            }
            if let difference = difference(between: value, and: writtenValue, path: key as String) {
                return LoggedReason("The written photo changed \(difference.path)", details: difference.values)
            }
        }
        let dataKey = kCGImageAuxiliaryDataInfoData
        for type in PhotoAuxiliaryImage.types {
            let originalInfo = original.auxiliaryInfo(of: type)
            guard !originalInfo.isEmpty else { continue }
            if (originalInfo[dataKey] as? Data) != (written.auxiliaryInfo(of: type)[dataKey] as? Data) {
                return LoggedReason("The written photo changed the auxiliary image \(type)")
            }
        }
        return nil
    }

    /// The first value the written one does not keep, nil when it keeps every one. A dictionary may gain keys, never
    /// lose them.
    static func difference(between original: Any, and written: Any, path: String) -> Difference? {
        switch (original, written) {
        case let (original as [String: Any], written as [String: Any]):
            for (key, value) in original {
                guard let writtenValue = written[key] else { return Difference(path: "\(path).\(key) (removed)") }
                if let difference = difference(between: value, and: writtenValue, path: "\(path).\(key)") {
                    return difference
                }
            }
            return nil
        case let (original as [Any], written as [Any]):
            guard original.count == written.count else { return Difference(path: path) }
            let pairs = zip(original, written).enumerated()
            return pairs.lazy.compactMap { offset, pair in
                difference(between: pair.0, and: pair.1, path: "\(path)[\(offset)]")
            }.first
        case let (original as Double, written as Double):
            let scale = max(abs(original), abs(written), 1)
            let isClose = abs(original - written) <= numberTolerance * scale
            return isClose ? nil : Difference(path: path, values: "\(original) to \(written)")
        case let (original as AnyHashable, written as AnyHashable):
            return original == written ? nil : Difference(path: path)
        default:
            return Difference(path: path)
        }
    }
}
