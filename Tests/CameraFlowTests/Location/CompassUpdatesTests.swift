//
//  CompassUpdatesTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation
import Foundation
import Testing
@testable import CameraFlow

/// What the compass of the photos' direction runs, and the errors that end its reading.
@Suite("The compass of the photos' direction")
struct CompassUpdatesTests {
    /// One situation of the compass and the updates it runs in it.
    struct Situation: Sendable, CustomTestStringConvertible {
        let name: String
        let isActive: Bool
        let hasCompass: Bool
        let followsLocation: Bool
        let authorization: LocationAuthorization
        let heading: Bool
        let location: Bool

        var testDescription: String {
            name
        }
    }

    static let situations = [
        Situation(
            name: "a stopped compass runs nothing",
            isActive: false,
            hasCompass: true,
            followsLocation: true,
            authorization: .authorized,
            heading: false,
            location: false
        ),
        Situation(
            name: "a device without a compass runs nothing",
            isActive: true,
            hasCompass: false,
            followsLocation: true,
            authorization: .authorized,
            heading: false,
            location: false
        ),
        Situation(
            name: "photos without a location take the magnetic heading alone",
            isActive: true,
            hasCompass: true,
            followsLocation: false,
            authorization: .authorized,
            heading: true,
            location: false
        ),
        Situation(
            name: "photos with a location and access follow the location for the true north",
            isActive: true,
            hasCompass: true,
            followsLocation: true,
            authorization: .authorized,
            heading: true,
            location: true
        ),
        Situation(
            name: "without an answer the location is not followed",
            isActive: true,
            hasCompass: true,
            followsLocation: true,
            authorization: .notDetermined,
            heading: true,
            location: false
        ),
        Situation(
            name: "a refused location is not followed",
            isActive: true,
            hasCompass: true,
            followsLocation: true,
            authorization: .denied,
            heading: true,
            location: false
        ),
        Situation(
            name: "a restricted location is not followed",
            isActive: true,
            hasCompass: true,
            followsLocation: true,
            authorization: .restricted,
            heading: true,
            location: false
        )
    ]

    @Test(
        "The compass runs the heading, and the location only for photos that record it, with access",
        arguments: situations
    )
    func updates(situation: Situation) {
        let updates = CompassUpdates(
            isActive: situation.isActive,
            hasCompass: situation.hasCompass,
            followsLocation: situation.followsLocation,
            authorization: situation.authorization
        )
        #expect(updates.heading == situation.heading)
        #expect(updates.location == situation.location)
    }

    @Test("A heading failure ends the reading")
    func headingFailure() {
        #expect(CompassReading.isEnded(by: CLError(.headingFailure)))
    }

    @Test(
        "An error of the location or of anything else leaves the reading",
        arguments: [CLError(.locationUnknown), CLError(.denied), CLError(.network)]
    )
    func otherLocationErrors(error: CLError) {
        #expect(CompassReading.isEnded(by: error) == false)
    }

    @Test("An error that is not Core Location's leaves the reading")
    func foreignError() {
        #expect(CompassReading.isEnded(by: CocoaError(.featureUnsupported)) == false)
    }
}
