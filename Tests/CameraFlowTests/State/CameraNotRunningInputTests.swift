//
//  CameraNotRunningInputTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

/// Touches, the shutter and the capture buttons over a camera that does not run: refused, not started yet or
/// paused. No input reaches such a camera.
@MainActor
@Suite("What the user does on a camera that does not run", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraNotRunningInputTests {
    let service = RecordingCameraService()
    private let point = CGPoint(x: 0.5, y: 0.5)

    @Test("A tap or a drag on the viewfinder of a refused camera neither focuses nor changes the exposure")
    func touchesOnRefusedCamera() async {
        service.authorization = .denied
        let model = makeCaptureModel(service: service)
        await model.start()
        model.viewfinderTapped(atUnitPoint: point, devicePoint: point)
        #expect(model.focus.reticle == nil)
        #expect(model.beginExposureDrag(atUnitPoint: point, devicePoint: point) == false)
        model.changeExposure(to: 1)
        #expect(model.settings.exposureBias == 0)
        #expect(service.calls.isEmpty)
        #expect(model.acceptsPinchZoom == false)
    }

    @Test("A tap on a failed camera still closes the open control panel")
    func tapClosesPanelOverFailure() async {
        service.startError = .cannotUseCamera("Busy")
        let model = makeCaptureModel(service: service)
        await model.start()
        model.panel.showTiles()
        #expect(model.panel.isOpen)
        model.viewfinderTapped(atUnitPoint: point, devicePoint: point)
        #expect(model.panel.isOpen == false)
        #expect(model.focus.reticle == nil)
    }

    @Test("The shutter waits for the camera to start, and takes photos once it runs")
    func shutterBeforeStart() async {
        let harness = FlowHarness(service: service)
        let flow = harness.makeFlow()
        #expect(flow.canShoot == false)
        #expect(flow.acceptsCaptureButtons == false)
        await flow.camera.start()
        #expect(flow.canShoot)
        #expect(flow.acceptsCaptureButtons)
    }

    @Test("A paused camera takes no photo: the shutter and the buttons are off, and a press does not blink")
    func pausedCamera() async {
        let harness = FlowHarness(service: service)
        let flow = harness.makeFlow()
        await flow.camera.start()
        await service.simulate(.interrupted(.cameraUnavailableBesideOtherApps))
        await settle { flow.camera.session.interruption != nil }
        #expect(flow.canShoot == false)
        #expect(flow.acceptsCaptureButtons == false)
        #expect(flow.camera.acceptsPinchZoom == false)
        await flow.camera.capture()
        #expect(flow.camera.shutter.captureCount == 0)
        #expect(service.captureRequests.isEmpty)
        #expect(flow.camera.notices.captureError == .interrupted(.cameraUnavailableBesideOtherApps))
        await service.simulate(.interruptionEnded)
        await settle { flow.camera.session.interruption == nil }
        #expect(flow.canShoot)
    }

    @Test("Only a shot that went to the camera blinks the viewfinder")
    func blinkOnlyWhenFired() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        model.stop()
        await model.capture()
        #expect(model.shutter.captureCount == 0)
        #expect(model.notices.captureError == .notRunning)
        await model.resume()
        service.captureError = .captureFailed("The sensor gave nothing")
        await model.capture()
        #expect(model.shutter.captureCount == 1)
        #expect(service.captureRequests.count == 1)
    }
}
