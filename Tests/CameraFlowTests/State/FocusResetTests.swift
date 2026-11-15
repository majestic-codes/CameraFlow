//
//  FocusResetTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Focus at a point gives way when the picture changes", .temporaryDirectory, .timeLimit(.minutes(1)))
struct FocusResetTests {
    let service = RecordingCameraService()
    let clock = ManualClock()

    func makeStartedModel() async -> PhotoCameraModel {
        let model = PhotoCameraModel(
            service: service,
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            clock: clock,
            files: CaptureTestSupport.makeFileStore()
        ) { _ in }
        await model.start()
        return model
    }

    @Test("A picture that changes after a tap brings back focus by itself and takes the reticle away")
    func resetAfterTap() async {
        let model = await makeStartedModel()
        let point = CGPoint(x: 0.3, y: 0.6)
        model.viewfinderTapped(atUnitPoint: point, devicePoint: point)
        #expect(model.focus.reticle?.location == point)
        await service.simulate(.subjectAreaChanged)
        #expect(model.focus.reticle == nil)
        #expect(service.calls.suffix(2) == [.focus(point), .resetFocus])
    }

    @Test("A picture that changes after the reticle went brings back focus by itself")
    func resetAfterReticleWent() async {
        let model = await makeStartedModel()
        model.viewfinderTapped(atUnitPoint: CGPoint(x: 0.5, y: 0.5), devicePoint: .zero)
        await clock.waitForSleepers()
        clock.advance(by: FocusModel.reticleLifetime)
        await settle { model.focus.reticle == nil }
        await service.simulate(.subjectAreaChanged)
        #expect(service.calls.last == .resetFocus)
    }

    @Test("A picture that changes while a finger changes the exposure keeps the focus and the reticle")
    func keptWhileAdjustingExposure() async {
        let model = await makeStartedModel()
        let point = CGPoint(x: 0.4, y: 0.4)
        model.viewfinderTapped(atUnitPoint: point, devicePoint: point)
        #expect(model.beginExposureDrag(atUnitPoint: point, devicePoint: point))
        await service.simulate(.subjectAreaChanged)
        #expect(model.focus.reticle?.location == point)
        #expect(model.focus.isAdjustingExposure)
        #expect(service.calls.contains(.resetFocus) == false)
        model.changeExposure(to: 1)
        #expect(model.settings.exposureBias == 1)
    }
}
