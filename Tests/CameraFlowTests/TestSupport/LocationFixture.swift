//
//  LocationFixture.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation
import Foundation

/// A location as Core Location reports one: a fix in Kyiv unless the test says otherwise, with its accuracy, course
/// and speed, taken at 2026-11-05 18:20:04.25 UTC.
enum LocationFixture {
    static let timestamp = Date(timeIntervalSince1970: 1_793_902_804.25)

    static func location(
        latitude: Double = 50.45,
        longitude: Double = 30.52,
        altitude: Double = 179,
        horizontalAccuracy: Double = 5,
        verticalAccuracy: Double = 3,
        course: Double = 271.5,
        speed: Double = 2.5
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: course,
            speed: speed,
            timestamp: timestamp
        )
    }
}
