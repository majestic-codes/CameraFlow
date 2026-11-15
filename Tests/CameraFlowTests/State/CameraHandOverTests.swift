//
//  CameraHandOverTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("What the camera model hands its models", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraHandOverTests {
    let service = RecordingCameraService()

    @Test("Every model takes the camera that started, and keeps the one before when a start fails")
    func startedCamera() async {
        let model = makeCaptureModel(service: service, isDualCameraOffered: true)
        await model.start()
        let back = model.session.capabilities
        #expect(back?.position == .back)
        #expect(model.zoom.capabilities == back)
        #expect(model.settings.photoCapabilities == SimulatedCameraService.iPhoneBackPhotoCapabilities)
        #expect(model.dualCamera.circlePosition == .front)
        service.startError = .cannotUseCamera("The camera is in use")
        await model.flipCamera()
        #expect(model.session.failure == .unavailable(.cannotUseCamera("The camera is in use")))
        #expect(model.zoom.capabilities == back)
        #expect(model.settings.photoCapabilities == SimulatedCameraService.iPhoneBackPhotoCapabilities)
        #expect(model.dualCamera.circlePosition == .front)
    }

    @Test("The pair tells the circle and the settings that it runs, and which camera is in the viewfinder")
    func pair() async {
        let model = makeCaptureModel(service: service, isDualCameraOffered: true)
        await model.start()
        await model.toggleDualCamera()
        #expect(model.dualCamera.isOn)
        #expect(model.settings.isDualCameraOn)
        #expect(model.settings.photoCapabilities == SimulatedCameraService.iPhoneDualPhotoCapabilities)
        await model.flipCamera()
        #expect(model.dualCamera.circlePosition == .back)
        await model.toggleDualCamera()
        #expect(model.dualCamera.isOn == false)
        #expect(model.settings.isDualCameraOn == false)
        #expect(model.dualCamera.circlePosition == .back)
    }

    @Test("A pair the device cannot run takes the circle's control off the top bar and leaves its tile inert")
    func unavailablePair() async {
        service.dualStartError = .dualCameraUnavailable("No pair of formats fits")
        let model = makeCaptureModel(service: service, isDualCameraOffered: true)
        await model.start()
        #expect(model.settings.topBarSettings == [.flash, .live, .dualCamera])
        await model.toggleDualCamera()
        #expect(model.settings.isDualCameraOffered == false)
        #expect(model.settings.topBarSettings == [.flash, .live])
        #expect(model.dualCamera.isToggleOffered == false)
        #expect(model.panel.settings.contains(.dualCamera))
    }
}
