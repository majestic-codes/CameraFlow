//
//  PhotoLocationFollowTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation
import Testing
@testable import CameraFlow

@MainActor
@Suite("The camera follows the location for its photos", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoLocationFollowTests {

    private func makeCamera(service: RecordingCameraService, location: FakeLocation) -> PhotoCameraModel {
        PhotoCameraModel(
            service: service,
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            onboarding: OnboardingModel(setting: .automatic, service: service, location: location),
            files: CaptureTestSupport.makeFileStore(),
            location: location
        ) { _ in }
    }

    @Test("The location is followed while the camera runs, and a photo takes the location of the moment")
    func followsTheCamera() async throws {
        let service = RecordingCameraService()
        let location = FakeLocation(authorization: .authorized)
        let fix = LocationFixture.location(latitude: 50.45, longitude: 30.52)
        location.currentLocation = fix
        let camera = makeCamera(service: service, location: location)
        await camera.start()
        #expect(location.followCalls == [true])
        await camera.capture()
        let request = try #require(service.captureRequests.first)
        #expect(request.location == fix)

        camera.stop()
        #expect(location.followCalls == [true, false])
        await camera.resume()
        #expect(location.followCalls == [true, false, true])
    }

    @Test("A photo taken with no location known goes without one")
    func noFix() async throws {
        let service = RecordingCameraService()
        let location = FakeLocation(authorization: .authorized)
        let camera = makeCamera(service: service, location: location)
        await camera.start()
        await camera.capture()
        let request = try #require(service.captureRequests.first)
        #expect(request.location == nil)
    }
}
