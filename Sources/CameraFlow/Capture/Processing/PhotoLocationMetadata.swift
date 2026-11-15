//
//  PhotoLocationMetadata.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation
import Foundation
import ImageIO

/// The location of a photo as the stock Camera writes it: the EXIF GPS dictionary of the photo, with the course of
/// the movement besides, and the ISO 6709 location of its Live Photo movie.
enum PhotoLocationMetadata {

    /// The GPS dictionary of a location and of the direction of the camera, empty when there is neither. The
    /// direction alone makes a dictionary with the direction only. The direction is both the image direction and
    /// the destination bearing, in degrees with its north as the reference.
    static func gpsDictionary(location: CLLocation?, heading: PhotoHeading?) -> [CFString: Any] {
        var gps = location.map(gpsDictionary(for:)) ?? [:]
        if let heading {
            gps[kCGImagePropertyGPSImgDirection] = heading.degrees
            gps[kCGImagePropertyGPSImgDirectionRef] = heading.north.reference
            gps[kCGImagePropertyGPSDestBearing] = heading.degrees
            gps[kCGImagePropertyGPSDestBearingRef] = heading.north.reference
        }
        return gps
    }

    /// The location as QuickTime metadata holds it (`com.apple.quicktime.location.ISO6709`): signed degrees of
    /// latitude and longitude to four decimals, the signed altitude in metres where the location reports it valid,
    /// and a closing slash, such as `+50.4500+030.5200+179.000/`.
    static func iso6709(for location: CLLocation) -> String {
        let coordinate = location.coordinate
        var text = String(format: "%+08.4f%+09.4f", coordinate.latitude, coordinate.longitude)
        if location.verticalAccuracy >= 0 {
            text += String(format: "%+08.3f", location.altitude)
        }
        return text + "/"
    }

    /// The GPS dictionary for `kCGImagePropertyGPSDictionary`. Values the location reports as invalid (a negative
    /// accuracy, speed or course) are left out. Speed is in kilometres per hour, the course in degrees from true
    /// north, and the time stamp in UTC.
    static func gpsDictionary(for location: CLLocation) -> [CFString: Any] {
        let coordinate = location.coordinate
        var gps: [CFString: Any] = [
            kCGImagePropertyGPSLatitude: abs(coordinate.latitude),
            kCGImagePropertyGPSLatitudeRef: coordinate.latitude < 0 ? "S" : "N",
            kCGImagePropertyGPSLongitude: abs(coordinate.longitude),
            kCGImagePropertyGPSLongitudeRef: coordinate.longitude < 0 ? "W" : "E",
            kCGImagePropertyGPSTimeStamp: location.timestamp.formatted(timeFormat),
            kCGImagePropertyGPSDateStamp: location.timestamp.formatted(dateFormat)
        ]
        if location.horizontalAccuracy >= 0 {
            gps[kCGImagePropertyGPSHPositioningError] = location.horizontalAccuracy
        }
        if location.verticalAccuracy >= 0 {
            gps[kCGImagePropertyGPSAltitude] = abs(location.altitude)
            // 0 is above sea level, 1 below.
            gps[kCGImagePropertyGPSAltitudeRef] = location.altitude < 0 ? 1 : 0
        }
        if location.speed >= 0 {
            gps[kCGImagePropertyGPSSpeed] = location.speed * secondsPerHour / metresPerKilometre
            gps[kCGImagePropertyGPSSpeedRef] = "K"
        }
        if location.course >= 0 {
            gps[kCGImagePropertyGPSTrack] = location.course
            gps[kCGImagePropertyGPSTrackRef] = "T"
        }
        return gps
    }

    private static let secondsPerHour = 3600.0
    private static let metresPerKilometre = 1000.0

    private static let calendar = Calendar(identifier: .gregorian)

    private static let timeFormat = Date.VerbatimFormatStyle(
        format: """
            \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\
            \(second: .twoDigits).\(secondFraction: .fractional(2))
            """,
        timeZone: .gmt,
        calendar: calendar
    )

    private static let dateFormat = Date.VerbatimFormatStyle(
        format: "\(year: .defaultDigits):\(month: .twoDigits):\(day: .twoDigits)",
        timeZone: .gmt,
        calendar: calendar
    )
}
