//
//  CameraSidesTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

/// A device with a camera on one side only, such as an iPhone or iPad app on a Mac or on Apple Vision Pro, where the
/// only camera is the front one: the flow opens on that camera and has nothing to flip to.
@MainActor
@Suite("The sides of the device that have a camera", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraSidesTests {
    let service = RecordingCameraService()

    @Test("A device with a front camera only opens on it, and a flip starts nothing and plays nothing")
    func frontOnly() async {
        service.cameraPositions = [.front]
        let haptics = RecordingCameraHaptics()
        let model = makeCaptureModel(service: service, haptics: haptics)
        #expect(model.session.position == .front)
        #expect(model.session.isFlipOffered == false)
        await model.start()
        #expect(service.calls.first == .start(.front))
        #expect(model.session.failure == nil)
        let calls = service.calls.count
        await model.flipCamera()
        #expect(service.calls.count == calls)
        #expect(haptics.events.contains(.cameraFlipped) == false)
        #expect(model.session.position == .front)
    }

    @Test("A device with a back camera only has nothing to flip to")
    func backOnly() async {
        service.cameraPositions = [.back]
        let model = makeCaptureModel(service: service)
        await model.start()
        let calls = service.calls.count
        await model.flipCamera()
        #expect(service.calls.count == calls)
        #expect(model.session.position == .back)
    }

    @Test("A device with a camera on both sides flips between them")
    func bothSides() async {
        let model = makeCaptureModel(service: service)
        #expect(model.session.isFlipOffered)
        await model.start()
        await model.flipCamera()
        #expect(model.session.position == .front)
    }

    @Test("A device without a camera is never asked for access and says the camera is missing")
    func noCamera() async {
        service.cameraPositions = []
        let model = makeCaptureModel(service: service)
        await model.start()
        #expect(model.session.failure == .unavailable(.noCamera))
        #expect(model.session.life == .refused)
        #expect(service.authorizationRequestCount == 0)
        #expect(service.calls.isEmpty)
    }
}
