//
//  ExposureDragModelTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Exposure drag in the model", .temporaryDirectory, .timeLimit(.minutes(1)))
struct ExposureDragModelTests {
    let service = RecordingCameraService()
    let clock = ManualClock()

    func makeModel() -> PhotoCameraModel {
        PhotoCameraModel(
            service: service,
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            clock: clock,
            files: CaptureTestSupport.makeFileStore()
        ) { _ in }
    }

    @Test("An exposure drag changes the bias the settings model holds and sends it to the camera")
    func exposureDrag() async {
        let model = makeModel()
        await model.start()
        model.viewfinderTapped(atUnitPoint: CGPoint(x: 0.5, y: 0.5), devicePoint: .zero)
        let began = model.beginExposureDrag(atUnitPoint: CGPoint(x: 0.2, y: 0.8), devicePoint: .zero)
        #expect(began)
        #expect(model.focus.reticle?.location == CGPoint(x: 0.5, y: 0.5))
        model.changeExposure(to: 1.25)
        #expect(model.settings.exposureBias == 1.25)
        #expect(service.calls.last == .exposureBias(1.25))
        model.changeExposure(to: 9)
        #expect(model.settings.exposureBias == 2)
        model.endExposureDrag()
        #expect(model.focus.isAdjustingExposure == false)
        model.changeExposure(to: -1)
        #expect(model.settings.exposureBias == 2)
    }

    @Test("An exposure drag with no reticle focuses where it began")
    func exposureDragFocuses() async {
        let model = makeModel()
        await model.start()
        let devicePoint = CGPoint(x: 0.3, y: 0.4)
        let began = model.beginExposureDrag(atUnitPoint: CGPoint(x: 0.2, y: 0.8), devicePoint: devicePoint)
        #expect(began)
        #expect(model.focus.reticle?.location == CGPoint(x: 0.2, y: 0.8))
        #expect(service.calls.contains(.focus(devicePoint)))
    }

    @Test("An exposure drag does nothing while the control panel is open")
    func exposureDragWithPanel() async {
        let model = makeModel()
        await model.start()
        model.panel.showTiles()
        let began = model.beginExposureDrag(atUnitPoint: CGPoint(x: 0.5, y: 0.5), devicePoint: .zero)
        #expect(began == false)
        model.changeExposure(to: 1)
        #expect(model.settings.exposureBias == 0)
        #expect(model.focus.reticle == nil)
    }

    @Test("The bias of a drag stays when a new point is tapped and is the one the panel shows")
    func exposureDragBiasStays() async {
        let model = makeModel()
        await model.start()
        model.viewfinderTapped(atUnitPoint: CGPoint(x: 0.5, y: 0.5), devicePoint: .zero)
        _ = model.beginExposureDrag(atUnitPoint: .zero, devicePoint: .zero)
        model.changeExposure(to: -0.7)
        model.endExposureDrag()
        model.viewfinderTapped(atUnitPoint: CGPoint(x: 0.1, y: 0.1), devicePoint: .zero)
        #expect(model.settings.exposureBias == -0.7)
        let expectedValue = (-0.7).formatted(.number.precision(.fractionLength(1)))
        #expect(CameraSettingText(.system).value(of: .exposure, in: model.settings) == expectedValue)
    }

    @Test("The reticle stays while a finger changes the exposure and its lifetime starts again on release")
    func exposureDragHoldsReticle() async {
        let model = makeModel()
        await model.start()
        model.viewfinderTapped(atUnitPoint: CGPoint(x: 0.5, y: 0.5), devicePoint: .zero)
        await clock.waitForSleepers()
        clock.advance(by: FocusModel.reticleLifetime - .milliseconds(1))
        _ = model.beginExposureDrag(atUnitPoint: .zero, devicePoint: .zero)
        #expect(clock.sleeperCount == 0)
        clock.advance(by: FocusModel.reticleLifetime * 3)
        await settleQueuedWork()
        #expect(model.focus.reticle != nil)
        model.endExposureDrag()
        await clock.waitForSleepers()
        clock.advance(by: FocusModel.reticleLifetime - .milliseconds(1))
        await settleQueuedWork()
        #expect(model.focus.reticle != nil)
        clock.advance(by: .milliseconds(1))
        await settle { model.focus.reticle == nil }
    }
}
