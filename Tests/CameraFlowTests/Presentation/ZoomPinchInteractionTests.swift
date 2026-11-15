//
//  ZoomPinchInteractionTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Pinch on the viewfinder", .timeLimit(.minutes(1)))
struct ZoomPinchInteractionTests {
    let service = RecordingCameraService()
    let haptics = RecordingCameraHaptics()
    let clock = ManualClock()
    let layout = LayoutWindow.referencePhone.layout(panelTileCount: 6)

    private struct Touches {
        let zoom: ZoomModel
        let dial: ZoomDialInteraction
        let pinch: ZoomPinchInteraction
    }

    /// The zoom of a started camera on its main lens, with the touch on the dial and the pinch over it.
    private func makeTouches(at position: CameraPosition = .back) async throws -> Touches {
        let zoom = try await makeStartedZoom(service: service, haptics: haptics, at: position)
        let dial = ZoomDialInteraction(zoom: zoom, clock: clock)
        return Touches(zoom: zoom, dial: dial, pinch: ZoomPinchInteraction(zoom: zoom, dial: dial))
    }

    /// Factors the camera was set to at once, in order.
    private var setFactors: [CGFloat] {
        service.calls.compactMap { call in
            guard case let .setZoom(factor) = call else { return nil }
            return factor
        }
    }

    private var lensRowCenter: CGPoint {
        CGPoint(x: layout.lensRow.midX, y: layout.lensRow.midY)
    }

    // MARK: - Zooming

    @Test("The camera gets the factor the pinch began at times every magnification, at once and without a ramp")
    func multiplies() async throws {
        let touches = try await makeTouches()
        touches.pinch.began(isEnabled: true)
        touches.pinch.changed(magnification: 1.5)
        touches.pinch.changed(magnification: 3)
        touches.pinch.changed(magnification: 0.75)
        #expect(setFactors == [1.5, 3, 0.75])
        #expect(touches.zoom.factor == 0.75)
        #expect(service.calls.contains(.rampZoom(0.75)) == false)
        touches.dial.cancelTimers()
    }

    @Test("The pinch stops at both ends of the camera's range", arguments: [(1000, 40), (0.001, 0.5)])
    func clamps(magnification: Double, expected: Double) async throws {
        let touches = try await makeTouches()
        touches.pinch.began(isEnabled: true)
        touches.pinch.changed(magnification: magnification)
        #expect(Double(touches.zoom.factor) == expected)
        #expect(setFactors.map { Double($0) } == [expected])
        touches.dial.cancelTimers()
    }

    @Test("The front camera zooms over its own range")
    func frontCamera() async throws {
        let touches = try await makeTouches(at: .front)
        touches.pinch.began(isEnabled: true)
        touches.pinch.changed(magnification: 2)
        #expect(touches.zoom.factor == 2)
        touches.pinch.changed(magnification: 9)
        #expect(touches.zoom.factor == 5)
        touches.pinch.changed(magnification: 0.2)
        #expect(touches.zoom.factor == 1)
        touches.dial.cancelTimers()
    }

    @Test("The pinch passes the lens factors without holding on to them or ticking")
    func noSnappingAndNoTicks() async throws {
        let touches = try await makeTouches()
        touches.pinch.began(isEnabled: true)
        let magnifications: [CGFloat] = [1.9, 1.99, 2.01, 2.1, 3.98, 4.02]
        for magnification in magnifications {
            touches.pinch.changed(magnification: magnification)
        }
        #expect(setFactors == magnifications)
        #expect(haptics.events.isEmpty)
        touches.dial.cancelTimers()
    }

    @Test("The lens buttons follow the pinch: the lens under the zoom is active and writes the current factor")
    func labels() async throws {
        let touches = try await makeTouches()
        let ukrainian = FlowLocalization(.specific(Locale.Language(identifier: "uk")))
        touches.pinch.began(isEnabled: true)
        touches.pinch.changed(magnification: 1.7)
        #expect(touches.zoom.activeLensIndex == 1)
        #expect(ZoomFactorTitle.current(touches.zoom.factor, localization: ukrainian) == "1,7×")
        touches.pinch.changed(magnification: 2.5)
        #expect(touches.zoom.activeLensIndex == 2)
        #expect(ZoomFactorTitle.current(touches.zoom.factor, localization: ukrainian) == "2,5×")
        touches.pinch.changed(magnification: 0.6)
        #expect(touches.zoom.activeLensIndex == 0)
        #expect(ZoomFactorTitle.current(touches.zoom.factor, localization: ukrainian) == "0,6×")
        #expect(service.captureControlLensIndexes == [2, 0])
        touches.dial.cancelTimers()
    }

    @Test("Lifting the fingers keeps the zoom and sends nothing more")
    func endKeepsFactor() async throws {
        let touches = try await makeTouches()
        touches.pinch.began(isEnabled: true)
        touches.pinch.changed(magnification: 2.4)
        touches.pinch.ended()
        #expect(touches.zoom.factor == 2.4)
        #expect(setFactors == [2.4])
        touches.pinch.changed(magnification: 5)
        #expect(touches.zoom.factor == 2.4)
        touches.dial.cancelTimers()
    }

    // MARK: - Where a pinch starts

    @Test("A new pinch starts from the zoom the last one left")
    func startsFromLastPinch() async throws {
        let touches = try await makeTouches()
        touches.pinch.began(isEnabled: true)
        touches.pinch.changed(magnification: 2)
        touches.pinch.ended()
        touches.pinch.began(isEnabled: true)
        touches.pinch.changed(magnification: 1.5)
        #expect(touches.zoom.factor == 3)
        touches.dial.cancelTimers()
    }

    @Test("A new pinch starts from the lens a tap on its button selected")
    func startsFromSelectedLens() async throws {
        let touches = try await makeTouches()
        touches.zoom.selectLens(at: 3)
        touches.pinch.began(isEnabled: true)
        touches.pinch.changed(magnification: 1.25)
        #expect(touches.zoom.factor == 5)
        touches.dial.cancelTimers()
    }

    @Test("A new pinch starts from the zoom the dial was turned to")
    func startsFromDialZoom() async throws {
        let touches = try await makeTouches()
        touches.zoom.openDial()
        touches.zoom.turnDial(to: 6)
        touches.zoom.closeDial()
        touches.pinch.began(isEnabled: true)
        touches.pinch.changed(magnification: 0.5)
        #expect(touches.zoom.factor == 3)
        touches.dial.cancelTimers()
    }

    // MARK: - Disabled

    @Test("A pinch that begins while the camera does not zoom changes nothing to its end")
    func disabled() async throws {
        let touches = try await makeTouches()
        touches.pinch.began(isEnabled: false)
        touches.pinch.changed(magnification: 3)
        touches.pinch.ended()
        #expect(touches.zoom.factor == 1)
        #expect(touches.zoom.isDialOpen == false)
        #expect(setFactors.isEmpty)
        #expect(clock.sleeperCount == 0)
    }

    @Test("Changes and an end without a pinch change nothing")
    func strayEvents() async throws {
        let touches = try await makeTouches()
        touches.pinch.changed(magnification: 3)
        touches.pinch.ended()
        #expect(touches.zoom.factor == 1)
        #expect(touches.zoom.isDialOpen == false)
        #expect(setFactors.isEmpty)
        #expect(clock.sleeperCount == 0)
    }

    @Test("A magnification that is not a number is ignored", arguments: [CGFloat.nan, .infinity])
    func notFinite(magnification: CGFloat) async throws {
        let touches = try await makeTouches()
        touches.pinch.began(isEnabled: true)
        touches.pinch.changed(magnification: magnification)
        #expect(touches.zoom.factor == 1)
        #expect(setFactors.isEmpty)
        touches.dial.cancelTimers()
    }

    // MARK: - The dial

    @Test("The dial shows while the fingers pinch and closes a while after they lift, as after a turn of it")
    func dialShowsAndHides() async throws {
        let touches = try await makeTouches()
        touches.pinch.began(isEnabled: true)
        #expect(touches.zoom.isDialOpen)
        touches.pinch.changed(magnification: 2)
        clock.advance(by: CameraMetrics.ZoomDial.closeDelay * 2)
        await settleQueuedWork()
        #expect(touches.zoom.isDialOpen)
        #expect(clock.sleeperCount == 0)
        touches.pinch.ended()
        await clock.waitForSleepers()
        clock.advance(by: CameraMetrics.ZoomDial.closeDelay - .milliseconds(1))
        await settleQueuedWork()
        #expect(touches.zoom.isDialOpen)
        clock.advance(by: .milliseconds(1))
        await settle { touches.zoom.isDialOpen == false }
        #expect(touches.zoom.factor == 2)
    }

    @Test("A new pinch while the dial waits to close keeps it open")
    func newPinchKeepsDialOpen() async throws {
        let touches = try await makeTouches()
        touches.pinch.began(isEnabled: true)
        touches.pinch.ended()
        await clock.waitForSleepers()
        touches.pinch.began(isEnabled: true)
        await settle { clock.sleeperCount == 0 }
        clock.advance(by: CameraMetrics.ZoomDial.closeDelay)
        await settleQueuedWork()
        #expect(touches.zoom.isDialOpen)
        touches.dial.cancelTimers()
    }

    @Test("A touch on the dial while it waits to close after a pinch keeps it open")
    func dialTouchKeepsDialOpen() async throws {
        let touches = try await makeTouches()
        touches.pinch.began(isEnabled: true)
        touches.pinch.ended()
        await clock.waitForSleepers()
        touches.dial.touchChanged(to: lensRowCenter, from: lensRowCenter, time: 0, in: layout)
        await settle { clock.sleeperCount == 0 }
        clock.advance(by: CameraMetrics.ZoomDial.closeDelay)
        await settleQueuedWork()
        #expect(touches.zoom.isDialOpen)
        touches.dial.cancelTimers()
    }

    @Test("A pinch that ends while a finger is on the dial leaves the closing to that finger")
    func pinchEndsUnderDialTouch() async throws {
        let touches = try await makeTouches()
        touches.pinch.began(isEnabled: true)
        touches.dial.touchChanged(to: lensRowCenter, from: lensRowCenter, time: 0, in: layout)
        touches.pinch.ended()
        await settleQueuedWork()
        #expect(clock.sleeperCount == 0)
        #expect(touches.zoom.isDialOpen)
        let lifted = CGPoint(x: lensRowCenter.x + CameraMetrics.LensRow.tapTravel + 1, y: lensRowCenter.y)
        touches.dial.touchEnded(at: lifted, from: lensRowCenter, in: layout)
        await clock.waitForSleepers()
        clock.advance(by: CameraMetrics.ZoomDial.closeDelay)
        await settle { touches.zoom.isDialOpen == false }
    }

    @Test("A pinch during a press on a lens button opens the dial, and the press selects no lens")
    func pinchDuringLensPress() async throws {
        let touches = try await makeTouches()
        let point = CGPoint(x: lensRowCenter.x + 2 * CameraMetrics.LensRow.pitch, y: lensRowCenter.y)
        touches.dial.touchChanged(to: point, from: point, time: 0, in: layout)
        #expect(touches.dial.pressedLensIndex == 3)
        touches.pinch.began(isEnabled: true)
        #expect(touches.dial.pressedLensIndex == nil)
        await settle { clock.sleeperCount == 0 }
        touches.pinch.changed(magnification: 1.5)
        #expect(touches.zoom.factor == 1.5)
        touches.dial.cancelTimers()
    }
}
