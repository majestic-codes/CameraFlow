//
//  PhotoLocationWriter.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import ImageIO

/// Adds a GPS dictionary to a photo file the camera wrote, without encoding the image again.
///
/// `CGImageDestinationCopyImageSource` copies the encoded image and every auxiliary image as they are, and writes
/// the photo's complete metadata with the GPS tags added to it. The merge mode of that call would be the narrower
/// tool, but it leaves a HEIF without the GPS tags (iOS 27.2, macOS 27), so the complete metadata replaces the old.
/// The result is read back and kept only when it has every property of the original plus the GPS dictionary, and
/// every auxiliary image unchanged (`PhotoMetadataLoss`). ImageIO cannot write a DNG, so a RAW photo cannot get a
/// location here.
enum PhotoLocationWriter {
    enum Outcome: Equatable {
        case located(Data)
        /// The file cannot get the GPS dictionary without losing something, and stays as the camera wrote it. The
        /// details of the reason are values of the photo's metadata.
        case unlocatable(LoggedReason)
    }

    static func addingGPS(_ gps: [CFString: Any], to data: Data) -> Outcome {
        let photo: ImageSourcePhoto
        do {
            photo = try ImageSourcePhoto(data: data)
        } catch {
            return .unlocatable(LoggedReason("The photo cannot be read"))
        }
        guard let metadata = photo.mutableMetadata() else {
            return .unlocatable(LoggedReason("The photo metadata cannot be copied"))
        }
        if let failure = set(gps, in: metadata) {
            return .unlocatable(failure)
        }
        let located: Data
        do {
            located = try ImageEncoding.data(
                copying: photo.source,
                typeIdentifier: photo.typeIdentifier,
                metadata: metadata,
                mergesMetadata: false
            )
        } catch {
            return .unlocatable(LoggedReason(error.description))
        }
        let gpsKey = kCGImagePropertyGPSDictionary as String
        if let loss = PhotoMetadataLoss.loss(from: photo, to: located, ignoring: [gpsKey]) {
            return .unlocatable(loss)
        }
        guard hasGPSDictionary(located) else {
            return .unlocatable(LoggedReason("The written photo has no GPS dictionary"))
        }
        return .located(located)
    }

    private static func hasGPSDictionary(_ data: Data) -> Bool {
        do {
            let written = try ImageSourcePhoto(data: data)
            return written.properties[kCGImagePropertyGPSDictionary] is [CFString: Any]
        } catch {
            return false
        }
    }

    /// Writes the GPS tags into the metadata, nil when every one is set. XMP holds the EXIF date stamp and time
    /// stamp as one date, `exif:GPSTimeStamp`, and setting either key alone overwrites it, so the two go in together.
    /// The file then has the time stamp to the second.
    private static func set(_ gps: [CFString: Any], in metadata: CGMutableImageMetadata) -> LoggedReason? {
        let dateKey = kCGImagePropertyGPSDateStamp
        let timeKey = kCGImagePropertyGPSTimeStamp
        let tags = gps.filter { key, _ in key != dateKey && key != timeKey }
        for (key, value) in tags {
            let isSet = CGImageMetadataSetValueMatchingImageProperty(
                metadata,
                kCGImagePropertyGPSDictionary,
                key,
                value as CFTypeRef
            )
            guard isSet else { return LoggedReason("Cannot set \(key) in the photo metadata") }
        }
        switch (gps[dateKey] as? String, gps[timeKey] as? String) {
        case (nil, nil):
            return nil
        case let (date?, time?):
            let timestamp = "\(date.replacingOccurrences(of: ":", with: "-"))T\(time)Z"
            let path = "exif:GPSTimeStamp" as CFString
            let isSet = CGImageMetadataSetValueWithPath(metadata, nil, path, timestamp as CFString)
            let failure = LoggedReason("Cannot set the GPS time stamp in the photo metadata", details: timestamp)
            return isSet ? nil : failure
        default:
            return LoggedReason("The GPS dictionary has a date stamp or a time stamp without the other")
        }
    }
}
