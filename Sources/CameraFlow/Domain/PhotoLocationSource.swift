//
//  PhotoLocationSource.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation

/// What the user allows the app for the location while it is in use.
enum LocationAuthorization: Sendable, Equatable {
    /// The user has not been asked yet.
    case notDetermined
    /// While in use or always, precise or approximate (`LocationPrecision`).
    case authorized
    /// The user said no, now or earlier, or turned Location Services off.
    case denied
    /// A device policy blocks the location and the user cannot change it.
    case restricted
}

/// How exactly the user lets the app know the location, the Precise Location switch of the system.
enum LocationPrecision: Sendable, Equatable {
    /// The location as exactly as the device knows it.
    case precise
    /// A location snapped to a point of the region the device is in, about 5 km off, which Core Location updates a
    /// few times an hour.
    case approximate
}

/// The location access of the app as the flow asks for it.
@MainActor
protocol LocationAuthorizer: AnyObject {
    var authorization: LocationAuthorization { get }
    /// Asks the user for when-in-use access and returns the answer once the user gave it. Returns the standing
    /// answer when there is one, and at once when the calling task is cancelled.
    func requestAuthorization() async -> LocationAuthorization
}

/// Where a photo takes the location it records from.
@MainActor
protocol PhotoLocationSource: AnyObject {

    /// Follows the location while the camera runs, as far as the access allows. It never asks for access.
    func start()
    func stop()
    /// The location for a photo taken now, nil when none is known that is recent enough.
    var location: CLLocation? { get }
}

/// The locations a photo may record.
enum PhotoLocationFix {

    /// The oldest a location of the precision may be to say where a photo taken now was taken. A camera follows the
    /// location while it is on screen, so a precise location older than a minute means the location stopped coming,
    /// and the user may have moved since. An approximate location comes a few times an hour, and Core Location
    /// documents one up to 20 minutes old.
    static func maximumAge(of precision: LocationPrecision) -> Duration {
        switch precision {
        case .precise: .seconds(60)
        case .approximate: .seconds(20 * 60)
        }
    }

    /// The location when it is valid and taken at most the maximum age of its precision before `date`, nil
    /// otherwise.
    static func recent(_ location: CLLocation?, at date: Date, precision: LocationPrecision) -> CLLocation? {
        guard let location, location.horizontalAccuracy >= 0 else { return nil }
        let age = date.timeIntervalSince(location.timestamp)
        let maximum = Double(maximumAge(of: precision).components.seconds)
        return age <= maximum ? location : nil
    }
}
