//
//  FocusReticleLifetimeTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

@MainActor
@Suite("The lifetime of the focus reticle", .temporaryDirectory, .timeLimit(.minutes(1)))
struct FocusReticleLifetimeTests {
    let service = RecordingCameraService()
    let clock = ManualClock()

    @Test("A tap during the lifetime of a reticle gives the new one a lifetime of its own, counted from the tap")
    func secondTap() async {
        let model = makeCaptureModel(service: service, clock: clock)
        await model.start()
        let first = CGPoint(x: 0.2, y: 0.3)
        let second = CGPoint(x: 0.7, y: 0.6)
        model.viewfinderTapped(atUnitPoint: first, devicePoint: first)
        await clock.waitForSleepers()
        clock.advance(by: .seconds(5))
        model.viewfinderTapped(atUnitPoint: second, devicePoint: second)
        await clock.waitForSleepers()
        clock.advance(by: FocusModel.reticleLifetime - .seconds(5))
        await settleQueuedWork()
        #expect(model.focus.reticle?.location == second)
        clock.advance(by: .seconds(5))
        await settle { model.focus.reticle == nil }
    }

    @Test("A tap that shows a reticle keeps it for its whole lifetime, and not longer")
    func lifetime() async {
        let model = makeCaptureModel(service: service, clock: clock)
        await model.start()
        let point = CGPoint(x: 0.4, y: 0.5)
        model.viewfinderTapped(atUnitPoint: point, devicePoint: point)
        await clock.waitForSleepers()
        clock.advance(by: FocusModel.reticleLifetime - .seconds(1))
        await settleQueuedWork()
        #expect(model.focus.reticle?.location == point)
        clock.advance(by: .seconds(1))
        await settle { model.focus.reticle == nil }
        #expect(clock.sleeperCount == 0)
    }
}
