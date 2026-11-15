//
//  ProvidedPhotoLocationTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation
import Testing
@testable import CameraFlow

/// The location of the app's `locationProvider`, held to the rule of the flow's own location.
@MainActor
@Suite("The location the app provides", .temporaryDirectory, .timeLimit(.minutes(1)))
struct ProvidedPhotoLocationTests {

    private func location(age: TimeInterval, horizontalAccuracy: Double = 5) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 50.45, longitude: 30.52),
            altitude: 179,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: 3,
            timestamp: Date.now.addingTimeInterval(-age)
        )
    }

    @Test("A fresh valid location is the photo's, read from the app at every photo")
    func fresh() {
        var calls = 0
        let fix = location(age: 1)
        let source = ProvidedPhotoLocation({
            calls += 1
            return fix
        }, precision: { .precise })
        source.start()
        #expect(source.location === fix)
        #expect(source.location === fix)
        #expect(calls == 2)
    }

    @Test("A precise location more than a minute old is not the photo's", arguments: [61.0, 3600])
    func stale(age: TimeInterval) {
        let source = ProvidedPhotoLocation({ location(age: age) }, precision: { .precise })
        #expect(source.location == nil)
    }

    @Test("An approximate location counts for 20 minutes, as the flow's own")
    func approximate() {
        let recent = location(age: 600, horizontalAccuracy: 4_800)
        let old = location(age: 1_300, horizontalAccuracy: 4_800)
        #expect(ProvidedPhotoLocation({ recent }, precision: { .approximate }).location === recent)
        #expect(ProvidedPhotoLocation({ old }, precision: { .approximate }).location == nil)
    }

    @Test("An invalid location and none at all give none")
    func invalid() {
        let invalid = location(age: 1, horizontalAccuracy: -1)
        #expect(ProvidedPhotoLocation({ invalid }, precision: { .precise }).location == nil)
        #expect(ProvidedPhotoLocation({ nil }, precision: { .precise }).location == nil)
    }

    @Test("A photo taken with a stale location of the app goes without one")
    func photoWithoutStaleLocation() async throws {
        let service = RecordingCameraService()
        let stale = location(age: 120)
        let model = PhotoCameraModel(
            service: service,
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            files: CaptureTestSupport.makeFileStore(),
            location: ProvidedPhotoLocation({ stale }, precision: { .precise })
        ) { _ in }
        await model.start()
        await model.capture()
        let request = try #require(service.captureRequests.first)
        #expect(request.location == nil)
    }
}
