//
//  FocusLockEndTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

/// What ends the AE/AF Lock and what does not: a tap elsewhere, another lens, a change of the camera and its stop end
/// it, a change of the picture and the exposure under it do not.
@MainActor
@Suite("What ends AE/AF Lock", .temporaryDirectory, .timeLimit(.minutes(1)))
struct FocusLockEndTests {
    let service = RecordingCameraService()
    let clock = ManualClock()
    private let point = CGPoint(x: 0.3, y: 0.6)

    /// A camera locked by a long press whose finger has let go.
    private func makeLockedModel() async -> PhotoCameraModel {
        let model = makeCaptureModel(service: service, clock: clock)
        await model.start()
        model.viewfinderPressBegan(atUnitPoint: point, devicePoint: point)
        await clock.waitForSleepers()
        clock.advance(by: FocusModel.lockDelay)
        await settle { model.focus.lock == .locked }
        model.viewfinderPressEnded()
        return model
    }

    @Test("A tap elsewhere ends the lock and focuses there, with a reticle that has its lifetime again")
    func tapElsewhere() async {
        let model = await makeLockedModel()
        let other = CGPoint(x: 0.7, y: 0.2)
        model.viewfinderTapped(atUnitPoint: other, devicePoint: other)
        #expect(model.focus.lock == nil)
        #expect(model.focus.reticle?.location == other)
        #expect(model.focus.reticle?.kind == .tap)
        #expect(service.calls.last == .focus(other))
        await clock.waitForSleepers()
        clock.advance(by: FocusModel.reticleLifetime)
        await settle { model.focus.reticle == nil }
    }

    @Test("A lens button ends the lock: the camera focuses and exposes by itself again and the reticle goes")
    func lensButton() async throws {
        let model = await makeLockedModel()
        let wide = try #require(model.zoom.lenses.firstIndex { $0.factor < 1 })
        model.zoom.selectLens(at: wide)
        #expect(model.focus.lock == nil)
        #expect(model.focus.reticle == nil)
        #expect(service.calls.suffix(2) == [.resetFocus, .rampZoom(model.zoom.lenses[wide].factor)])
    }

    @Test("A zoom within the lens keeps the lock, and one into the next lens ends it")
    func zoomAcrossLenses() async throws {
        let model = await makeLockedModel()
        let lens = try #require(model.zoom.activeLensIndex)
        let next = try #require(model.zoom.lenses.dropFirst(lens + 1).first)
        let within = (model.zoom.lenses[lens].factor + next.factor) / 2
        model.zoom.setZoom(within)
        #expect(model.zoom.activeLensIndex == lens)
        #expect(model.focus.lock == .locked)
        #expect(service.calls.contains(.resetFocus) == false)
        model.zoom.setZoom(next.factor)
        #expect(model.focus.lock == nil)
        #expect(service.calls.contains(.resetFocus))
    }

    @Test("A flip of the camera ends the lock")
    func flip() async {
        let model = await makeLockedModel()
        await model.flipCamera()
        #expect(model.focus.lock == nil)
        #expect(model.focus.reticle == nil)
    }

    @Test("A camera stopped on purpose ends the lock, and the camera that starts again has none")
    func stop() async {
        let model = await makeLockedModel()
        model.stop()
        #expect(model.focus.lock == nil)
        #expect(model.focus.reticle == nil)
        await model.resume()
        #expect(model.focus.lock == nil)
    }

    @Test("A change of the picture keeps the lock, the focus and the reticle")
    func subjectAreaChange() async {
        let model = await makeLockedModel()
        let callCount = service.calls.count
        await service.simulate(.subjectAreaChanged)
        #expect(model.focus.lock == .locked)
        #expect(model.focus.reticle?.location == point)
        #expect(service.calls(after: callCount).isEmpty)
    }

    @Test("The exposure still changes under the lock, by a drag and by the sun's element, and the reticle stays")
    func exposureUnderTheLock() async {
        let model = await makeLockedModel()
        #expect(model.beginExposureDrag(atUnitPoint: point, devicePoint: point))
        model.changeExposure(to: 1)
        model.endExposureDrag()
        #expect(model.settings.exposureBias == 1)
        #expect(service.calls.last == .exposureBias(1))
        model.adjustExposure(by: -0.5)
        #expect(model.settings.exposureBias == 0.5)
        await settleQueuedWork()
        #expect(clock.sleeperCount == 0)
        #expect(model.focus.lock == .locked)
        #expect(model.focus.reticle?.location == point)
    }

    @Test("A lock that a tap ends in the turn it began is never asked of the camera, so the tap's focus holds")
    func lockEndedAtOnce() async {
        let model = makeCaptureModel(service: service, clock: clock)
        await model.start()
        let callCount = service.calls.count
        let other = CGPoint(x: 0.7, y: 0.2)
        model.viewfinderPressBegan(atUnitPoint: point, devicePoint: point)
        model.viewfinderTapped(atUnitPoint: other, devicePoint: other)
        await settleQueuedWork()
        #expect(service.calls(after: callCount) == [.focus(other)])
        #expect(model.focus.lock == nil)
        #expect(model.focus.reticle?.location == other)
    }

    @Test("A camera's answer that comes after a tap ended the lock is dropped")
    func lateAnswerDropped() async {
        service.holdsFocusLock = true
        let model = makeCaptureModel(service: service, clock: clock)
        await model.start()
        model.viewfinderPressBegan(atUnitPoint: point, devicePoint: point)
        await settle { service.isFocusLockHeld }
        await clock.waitForSleepers()
        clock.advance(by: FocusModel.lockDelay)
        await settle { model.focus.lock == .settling }
        service.settleFocusLock()
        let other = CGPoint(x: 0.7, y: 0.2)
        model.viewfinderTapped(atUnitPoint: other, devicePoint: other)
        await settleQueuedWork()
        #expect(model.focus.lock == nil)
        #expect(model.focus.reticle?.location == other)
    }

    @Test("A lock the camera gives up ends, and the reticle has its lifetime once the finger lets go")
    func cameraGivesUp() async {
        service.holdsFocusLock = true
        let model = makeCaptureModel(service: service, clock: clock)
        await model.start()
        model.viewfinderPressBegan(atUnitPoint: point, devicePoint: point)
        await settle { service.isFocusLockHeld }
        service.stop()
        await settle { model.focus.lock == nil }
        await settleQueuedWork()
        #expect(model.focus.reticle?.location == point)
        #expect(clock.sleeperCount == 0)
        model.viewfinderPressEnded()
        await clock.waitForSleepers()
        clock.advance(by: FocusModel.reticleLifetime)
        await settle { model.focus.reticle == nil }
    }
}
