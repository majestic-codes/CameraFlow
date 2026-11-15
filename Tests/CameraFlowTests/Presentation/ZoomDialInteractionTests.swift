//
//  ZoomDialInteractionTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Touch on the lens row and the zoom dial", .timeLimit(.minutes(1)))
struct ZoomDialInteractionTests {
    let service = RecordingCameraService()
    let clock = ManualClock()
    let layout = LayoutWindow.referencePhone.layout(panelTileCount: 6)

    /// The zoom of a started back camera, on its main lens at index 1, and the interaction over it.
    private func makeInteraction() async throws -> (zoom: ZoomModel, interaction: ZoomDialInteraction) {
        let zoom = try await makeStartedZoom(service: service)
        return (zoom, ZoomDialInteraction(zoom: zoom, clock: clock))
    }

    /// The centre of a lens button while the main lens is the active one.
    private func lensCenter(_ index: Int) -> CGPoint {
        let row = layout.lensRow
        return CGPoint(x: row.midX + CGFloat(index - 1) * CameraMetrics.LensRow.pitch, y: row.midY)
    }

    /// The calls that moved the zoom.
    private var zoomCalls: [RecordingCameraService.Call] {
        service.calls.filter { call in
            switch call {
            case .setZoom, .rampZoom: true
            default: false
            }
        }
    }

    private var zoomWasSet: Bool {
        service.calls.contains { call in
            if case .setZoom = call { true } else { false }
        }
    }

    @Test("A tap on a lens button selects that lens")
    func tapSelectsLens() async throws {
        let (zoom, interaction) = try await makeInteraction()
        let point = lensCenter(3)
        interaction.touchChanged(to: point, from: point, time: 0, in: layout)
        #expect(interaction.pressedLensIndex == 3)
        interaction.touchEnded(at: point, from: point, in: layout)
        #expect(interaction.pressedLensIndex == nil)
        #expect(zoom.factor == 4)
        #expect(zoom.isDialOpen == false)
        #expect(service.calls.last == .rampZoom(4))
        await settle { clock.sleeperCount == 0 }
    }

    @Test("A press that ends on another lens button selects nothing")
    func releaseElsewhere() async throws {
        let (zoom, interaction) = try await makeInteraction()
        let start = lensCenter(3)
        interaction.touchChanged(to: start, from: start, time: 0, in: layout)
        interaction.touchEnded(at: lensCenter(2), from: start, in: layout)
        #expect(zoom.factor == 1)
        #expect(service.calls == [.start(.back)])
    }

    @Test("A touch on the lens row of a camera that has not started presses no lens and selects none")
    func touchWithoutCamera() async {
        let zoom = ZoomModel(service: service, haptics: RecordingCameraHaptics())
        let interaction = ZoomDialInteraction(zoom: zoom, clock: clock)
        let point = CGPoint(x: layout.lensRow.midX, y: layout.lensRow.midY)
        interaction.touchChanged(to: point, from: point, time: 0, in: layout)
        #expect(interaction.pressedLensIndex == nil)
        interaction.touchEnded(at: point, from: point, in: layout)
        #expect(zoomCalls.isEmpty)
        interaction.cancelTimers()
        await settle { clock.sleeperCount == 0 }
    }

    @Test("A touch above the lens row or past its last button presses no lens")
    func touchBesideButtons() async throws {
        let (zoom, interaction) = try await makeInteraction()
        let row = layout.lensRow
        let above = CGPoint(x: row.midX, y: row.minY - CameraMetrics.LensRow.touchSlop - 4)
        interaction.touchChanged(to: above, from: above, time: 0, in: layout)
        #expect(interaction.pressedLensIndex == nil)
        interaction.touchEnded(at: above, from: above, in: layout)
        let pastLast = CGPoint(x: row.midX + 4 * CameraMetrics.LensRow.pitch, y: row.midY)
        interaction.touchChanged(to: pastLast, from: pastLast, time: 1, in: layout)
        #expect(interaction.pressedLensIndex == nil)
        interaction.touchEnded(at: pastLast, from: pastLast, in: layout)
        #expect(zoom.factor == 1)
        #expect(zoomCalls.isEmpty)
        interaction.cancelTimers()
        await settle { clock.sleeperCount == 0 }
    }

    @Test("A touch that ends without having begun selects nothing and leaves the dial closed")
    func endWithoutBeginning() async throws {
        let (zoom, interaction) = try await makeInteraction()
        let point = CGPoint(x: layout.lensRow.midX + CameraMetrics.LensRow.pitch, y: layout.lensRow.midY)
        interaction.touchEnded(at: point, from: point, in: layout)
        #expect(zoom.factor == 1)
        #expect(zoom.isDialOpen == false)
        #expect(zoomCalls.isEmpty)
        await settle { clock.sleeperCount == 0 }
    }

    @Test("A press held for the open delay opens the dial, which closes a while after the finger lifts")
    func holdOpensDial() async throws {
        let (zoom, interaction) = try await makeInteraction()
        let point = lensCenter(1)
        interaction.touchChanged(to: point, from: point, time: 0, in: layout)
        await clock.waitForSleepers()
        clock.advance(by: CameraMetrics.ZoomDial.openDelay - .milliseconds(1))
        await settleQueuedWork()
        #expect(zoom.isDialOpen == false)
        clock.advance(by: .milliseconds(1))
        await settle { zoom.isDialOpen }
        #expect(interaction.pressedLensIndex == nil)
        interaction.touchEnded(at: point, from: point, in: layout)
        #expect(zoom.factor == 1)
        await clock.waitForSleepers()
        clock.advance(by: CameraMetrics.ZoomDial.closeDelay - .milliseconds(1))
        await settleQueuedWork()
        #expect(zoom.isDialOpen)
        clock.advance(by: .milliseconds(1))
        await settle { zoom.isDialOpen == false }
    }

    @Test("A press dragged sideways past the travel opens the dial at once and turns it")
    func dragOpensDial() async throws {
        let (zoom, interaction) = try await makeInteraction()
        let start = lensCenter(1)
        interaction.touchChanged(to: start, from: start, time: 0, in: layout)
        let within = CGPoint(x: start.x + CameraMetrics.LensRow.pressSidewaysTravel, y: start.y)
        interaction.touchChanged(to: within, from: start, time: 0.02, in: layout)
        #expect(zoom.isDialOpen == false)
        #expect(zoomWasSet == false)
        let beyond = CGPoint(x: start.x + CameraMetrics.LensRow.pressSidewaysTravel + 1, y: start.y)
        interaction.touchChanged(to: beyond, from: start, time: 0.04, in: layout)
        #expect(zoom.isDialOpen)
        #expect(interaction.pressedLensIndex == nil)
        #expect(zoomWasSet)
        interaction.cancelTimers()
    }

    @Test("A drag on the lens row that a sub-panel lifted opens the dial there")
    func dragOpensDialOverSubPanel() async throws {
        let (zoom, interaction) = try await makeInteraction()
        let lifted = CameraScreenLayout(
            size: layout.size,
            safeAreaTop: 62,
            panel: .subPanel(.format),
            panelTileCount: 6
        )
        let start = CGPoint(x: lifted.lensRow.midX, y: lifted.lensRow.midY)
        interaction.touchChanged(to: start, from: start, time: 0, in: lifted)
        let beyond = CGPoint(x: start.x + CameraMetrics.LensRow.pressSidewaysTravel + 1, y: start.y)
        interaction.touchChanged(to: beyond, from: start, time: 0.04, in: lifted)
        #expect(zoom.isDialOpen)
        #expect(zoomWasSet)
        interaction.cancelTimers()
    }

    @Test("A new touch while the dial waits to close keeps it open")
    func touchKeepsDialOpen() async throws {
        let (zoom, interaction) = try await makeInteraction()
        zoom.openDial()
        let point = lensCenter(1)
        let lifted = CGPoint(x: point.x + CameraMetrics.LensRow.tapTravel + 1, y: point.y)
        interaction.touchChanged(to: point, from: point, time: 0, in: layout)
        interaction.touchEnded(at: lifted, from: point, in: layout)
        await clock.waitForSleepers()
        interaction.touchChanged(to: point, from: point, time: 1, in: layout)
        await settle { clock.sleeperCount == 0 }
        clock.advance(by: CameraMetrics.ZoomDial.closeDelay)
        await settleQueuedWork()
        #expect(zoom.isDialOpen)
    }

    @Test("A tap on a label of the open dial zooms there and closes the dial")
    func tapOnDialLabel() async throws {
        let (zoom, interaction) = try await makeInteraction()
        zoom.openDial()
        let geometry = ZoomDialGeometry(center: layout.zoomDialCenter, radius: CameraMetrics.ZoomDial.radius)
        let angle = zoom.scale.angle(of: 2, current: zoom.factor)
        let label = geometry.point(at: angle, inset: CameraMetrics.ZoomDial.labelInset)
        interaction.touchChanged(to: label, from: label, time: 0, in: layout)
        interaction.touchEnded(at: label, from: label, in: layout)
        #expect(zoom.factor == 2)
        #expect(zoom.isDialOpen == false)
        #expect(service.calls.last == .setZoom(2))
        #expect(clock.sleeperCount == 0)
    }

    @Test("Cancelling the timers keeps a held press from opening the dial")
    func cancelTimers() async throws {
        let (zoom, interaction) = try await makeInteraction()
        let point = lensCenter(1)
        interaction.touchChanged(to: point, from: point, time: 0, in: layout)
        await clock.waitForSleepers()
        interaction.cancelTimers()
        await settle { clock.sleeperCount == 0 }
        clock.advance(by: CameraMetrics.ZoomDial.openDelay)
        await settleQueuedWork()
        #expect(zoom.isDialOpen == false)
    }
}
