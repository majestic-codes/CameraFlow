//
//  PhotoHeadingFixTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@Suite("The heading a compass reading gives")
struct PhotoHeadingFixTests {
    private static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private static func reading(
        trueHeading: Double = 92,
        magneticHeading: Double = 88,
        accuracy: Double = 10,
        age: TimeInterval = 1
    ) -> CompassReading {
        CompassReading(
            trueHeading: trueHeading,
            magneticHeading: magneticHeading,
            accuracy: accuracy,
            timestamp: now.addingTimeInterval(-age)
        )
    }

    @Test("A reading with the true north gives the true heading")
    func trueNorth() {
        let heading = PhotoHeadingFix.heading(of: Self.reading(), at: Self.now)
        #expect(heading == PhotoHeading(degrees: 92, north: .geographic))
    }

    @Test("A reading without the true north, as without a location, gives the magnetic heading")
    func magneticNorth() {
        let heading = PhotoHeadingFix.heading(of: Self.reading(trueHeading: -1), at: Self.now)
        #expect(heading == PhotoHeading(degrees: 88, north: .magnetic))
    }

    @Test("No reading gives no heading")
    func noReading() {
        #expect(PhotoHeadingFix.heading(of: nil, at: Self.now) == nil)
    }

    @Test(
        "An invalid, inaccurate or old reading gives no heading",
        arguments: [
            ("invalid accuracy", reading(accuracy: -1)),
            ("more than 45 degrees off", reading(accuracy: 46)),
            ("older than 5 seconds", reading(age: 6)),
            ("no heading at all", reading(trueHeading: -1, magneticHeading: -1)),
            ("not a number", reading(trueHeading: .nan, magneticHeading: .nan))
        ]
    )
    func rejected(name: String, reading: CompassReading) {
        #expect(PhotoHeadingFix.heading(of: reading, at: Self.now) == nil, "\(name)")
    }

    @Test("A reading at the limits still counts, and 360 degrees is north")
    func limits() {
        let edge = PhotoHeadingFix.heading(of: Self.reading(trueHeading: 360, accuracy: 45, age: 5), at: Self.now)
        #expect(edge == PhotoHeading(degrees: 0, north: .geographic))
    }
}
