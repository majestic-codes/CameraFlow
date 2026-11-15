//
//  PhotoHeading.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 13.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// Where the camera pointed when a photo was taken, as the EXIF GPS image direction writes it: degrees clockwise
/// from north, and which north.
///
/// It is the direction of the camera, from the compass, never the direction the phone moved in
/// (`CLLocation.course`), which the GPS dictionary writes apart as the track.
struct PhotoHeading: Sendable, Equatable {
    /// The north the degrees count from.
    enum North: Sendable, Equatable {
        /// The geographic north pole, `GPSImgDirectionRef` "T".
        case geographic
        /// The magnetic north pole, `GPSImgDirectionRef` "M".
        case magnetic

        /// The reference the EXIF GPS dictionary names it with.
        var reference: String {
            switch self {
            case .geographic: "T"
            case .magnetic: "M"
            }
        }
    }

    /// Degrees clockwise from `north`, in 0..<360.
    let degrees: Double
    let north: North
}

/// One reading of the compass in the values Core Location gives it, so it is checked without a `CLHeading`.
struct CompassReading: Sendable, Equatable {
    /// Degrees from the geographic north, negative when Core Location could not tell it, which it cannot without
    /// a location.
    let trueHeading: Double
    /// Degrees from the magnetic north.
    let magneticHeading: Double
    /// The most the heading may be off by, in degrees. Negative when the heading is invalid.
    let accuracy: Double
    let timestamp: Date
}

/// The headings a photo may record.
enum PhotoHeadingFix {
    /// The oldest a reading may be. The compass reports every sample while the camera is on screen, also while the
    /// phone is held still, so a reading this old means it stopped reporting, and the phone may have turned since.
    static let maximumAge: Duration = .seconds(5)
    /// The largest error a reading may have, in degrees. A larger one, such as next to a magnet before the compass
    /// is calibrated, would name the wrong side of the scene.
    static let maximumError = 45.0

    /// The heading of a reading that is valid, accurate and recent, nil otherwise. The geographic north wins where
    /// the reading has it, the magnetic one is taken otherwise.
    static func heading(of reading: CompassReading?, at date: Date) -> PhotoHeading? {
        guard let reading, reading.accuracy >= 0, reading.accuracy <= maximumError else { return nil }
        let age = date.timeIntervalSince(reading.timestamp)
        guard age <= Double(maximumAge.components.seconds) else { return nil }
        if let degrees = normalized(reading.trueHeading) {
            return PhotoHeading(degrees: degrees, north: .geographic)
        }
        return normalized(reading.magneticHeading).map { PhotoHeading(degrees: $0, north: .magnetic) }
    }

    /// The degrees in 0..<360, nil for a negative value, which Core Location reports for an unknown heading.
    private static func normalized(_ degrees: Double) -> Double? {
        guard degrees >= 0, degrees.isFinite else { return nil }
        return degrees.truncatingRemainder(dividingBy: 360)
    }
}

/// Where a photo takes the direction of the camera from.
@MainActor
protocol PhotoHeadingSource: AnyObject {

    /// Follows the compass while the camera runs.
    func start()
    func stop()
    /// Tells the compass how the phone is held, so that it measures the direction the back of the phone faces in
    /// every quarter.
    func deviceOrientationChanged(to orientation: CameraOrientation)
    /// The direction of the camera for a photo taken now, nil when no valid, accurate and recent reading is known.
    var heading: PhotoHeading? { get }
}
