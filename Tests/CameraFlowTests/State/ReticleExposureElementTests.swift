//
//  ReticleExposureElementTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

/// The adjustable Exposure element of the reticle for VoiceOver: an adjustment keeps the reticle, and with it the
/// element, on screen for the reticle's lifetime again.
@MainActor
@Suite("The reticle's exposure element", .temporaryDirectory, .timeLimit(.minutes(1)))
struct ReticleExposureElementTests {

    @Test("An adjustment just before the reticle's lifetime ends keeps the reticle for another lifetime")
    func adjustmentKeepsReticle() async {
        let service = RecordingCameraService()
        let clock = ManualClock()
        let model = makeCaptureModel(service: service, clock: clock)
        await model.start()
        let point = CGPoint(x: 0.5, y: 0.5)
        model.viewfinderTapped(atUnitPoint: point, devicePoint: point)
        await clock.waitForSleepers()
        clock.advance(by: FocusModel.reticleLifetime - .seconds(1))
        model.adjustExposure(by: 0.5)
        #expect(model.settings.exposureBias == 0.5)
        #expect(service.calls.last == .exposureBias(0.5))
        await clock.waitForSleepers()
        clock.advance(by: FocusModel.reticleLifetime - .seconds(1))
        await settleQueuedWork()
        #expect(model.focus.reticle != nil)
        clock.advance(by: .seconds(1))
        await settle { model.focus.reticle == nil }
    }

    @Test("An adjustment without a reticle shows none")
    func adjustmentWithoutReticle() async {
        let model = makeCaptureModel(service: RecordingCameraService())
        await model.start()
        model.adjustExposure(by: -0.5)
        #expect(model.focus.reticle == nil)
        #expect(model.settings.exposureBias == -0.5)
    }
}
