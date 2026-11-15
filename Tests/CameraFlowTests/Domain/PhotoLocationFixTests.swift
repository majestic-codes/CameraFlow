//
//  PhotoLocationFixTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation
import Testing
@testable import CameraFlow

@MainActor
@Suite("The location a photo may record")
struct PhotoLocationFixTests {
    private static let taken = Date(timeIntervalSince1970: 1_794_000_000)
    /// The accuracy of an approximate location, in metres.
    private static let approximateAccuracy = 4_800.0

    private func location(horizontalAccuracy: Double = 5) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 50.45, longitude: 30.52),
            altitude: 179,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: 3,
            timestamp: Self.taken
        )
    }

    @Test("A precise location up to a minute old is the photo's", arguments: [0, 30, 60])
    func recent(seconds: Double) {
        let fix = location()
        let date = Self.taken.addingTimeInterval(seconds)
        #expect(PhotoLocationFix.recent(fix, at: date, precision: .precise) === fix)
    }

    @Test("An older precise location is not", arguments: [61, 600])
    func stale(seconds: Double) {
        let date = Self.taken.addingTimeInterval(seconds)
        #expect(PhotoLocationFix.recent(location(), at: date, precision: .precise) == nil)
    }

    @Test(
        "An approximate location, which Core Location updates a few times an hour, is the photo's for 20 minutes",
        arguments: [0, 61, 600, 1200]
    )
    func recentApproximate(seconds: Double) {
        let fix = location(horizontalAccuracy: Self.approximateAccuracy)
        let date = Self.taken.addingTimeInterval(seconds)
        #expect(PhotoLocationFix.recent(fix, at: date, precision: .approximate) === fix)
    }

    @Test("An approximate location older than 20 minutes is not", arguments: [1201, 1260, 3600])
    func staleApproximate(seconds: Double) {
        let fix = location(horizontalAccuracy: Self.approximateAccuracy)
        let date = Self.taken.addingTimeInterval(seconds)
        #expect(PhotoLocationFix.recent(fix, at: date, precision: .approximate) == nil)
    }

    @Test("An invalid location and none at all give none", arguments: [LocationPrecision.precise, .approximate])
    func invalid(precision: LocationPrecision) {
        let invalid = location(horizontalAccuracy: -1)
        #expect(PhotoLocationFix.recent(invalid, at: Self.taken, precision: precision) == nil)
        #expect(PhotoLocationFix.recent(nil, at: Self.taken, precision: precision) == nil)
    }
}
