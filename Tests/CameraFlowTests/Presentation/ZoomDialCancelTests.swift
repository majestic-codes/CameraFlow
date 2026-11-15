//
//  ZoomDialCancelTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

/// A touch on the zoom control that the system takes away, and a tap on the open dial near a label it hides.
@MainActor
@Suite("Touch on the zoom control taken away, and taps on the hidden part of the dial", .timeLimit(.minutes(1)))
struct ZoomDialCancelTests {
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
        let row = LensRowLayout(row: layout.lensRow, lensCount: 5, activeIndex: 1)
        return CGPoint(x: row.centerX(of: index), y: layout.lensRow.midY)
    }

    /// Where the label of a factor stands on the open dial.
    private func labelCenter(of factor: CGFloat, zoom: ZoomModel) -> CGPoint {
        let geometry = ZoomDialGeometry(center: layout.zoomDialCenter, radius: CameraMetrics.ZoomDial.radius)
        let angle = zoom.scale.angle(of: factor, current: zoom.factor)
        return geometry.point(at: angle, inset: CameraMetrics.ZoomDial.labelInset)
    }

    @Test("A press taken away before the dial opens selects no lens and opens nothing")
    func shortPress() async throws {
        let (zoom, interaction) = try await makeInteraction()
        let point = lensCenter(3)
        interaction.touchChanged(to: point, from: point, time: 0, in: layout)
        #expect(interaction.pressedLensIndex == 3)
        await clock.waitForSleepers()
        interaction.touchCancelled()
        #expect(interaction.pressedLensIndex == nil)
        await settle { clock.sleeperCount == 0 }
        clock.advance(by: CameraMetrics.ZoomDial.openDelay)
        await settleQueuedWork()
        #expect(zoom.isDialOpen == false)
        #expect(zoom.factor == 1)
        #expect(service.calls == [.start(.back)])
    }

    @Test("A turn taken away leaves the dial to close a while later")
    func openDial() async throws {
        let (zoom, interaction) = try await makeInteraction()
        let start = lensCenter(1)
        interaction.touchChanged(to: start, from: start, time: 0, in: layout)
        let beyond = CGPoint(x: start.x + CameraMetrics.LensRow.pressSidewaysTravel + 1, y: start.y)
        interaction.touchChanged(to: beyond, from: start, time: 0.04, in: layout)
        #expect(zoom.isDialOpen)
        interaction.touchCancelled()
        await clock.waitForSleepers()
        clock.advance(by: CameraMetrics.ZoomDial.closeDelay)
        await settle { zoom.isDialOpen == false }
    }

    @Test("A pinch that ends after a touch was taken away closes the dial it held open")
    func releaseAfterCancel() async throws {
        let (zoom, interaction) = try await makeInteraction()
        let point = lensCenter(1)
        interaction.touchChanged(to: point, from: point, time: 0, in: layout)
        interaction.holdDialOpen()
        interaction.touchCancelled()
        interaction.cancelTimers()
        await settle { clock.sleeperCount == 0 }
        interaction.releaseDial()
        await clock.waitForSleepers()
        clock.advance(by: CameraMetrics.ZoomDial.closeDelay)
        await settle { zoom.isDialOpen == false }
    }

    @Test("A new touch after one was taken away starts afresh: the zoom does not jump to the new finger")
    func freshTouch() async throws {
        let (zoom, interaction) = try await makeInteraction()
        zoom.openDial()
        let first = CGPoint(x: layout.zoomDial.midX - 100, y: layout.zoomDial.midY)
        interaction.touchChanged(to: first, from: first, time: 0, in: layout)
        interaction.touchCancelled()
        let second = CGPoint(x: layout.zoomDial.midX + 100, y: layout.zoomDial.midY)
        interaction.touchChanged(to: second, from: second, time: 1, in: layout)
        #expect(zoom.factor == 1)
        interaction.touchCancelled()
        interaction.cancelTimers()
    }

    @Test("A taken-away touch that never began changes nothing")
    func strayCancel() async throws {
        let (zoom, interaction) = try await makeInteraction()
        interaction.touchCancelled()
        #expect(zoom.isDialOpen == false)
        #expect(clock.sleeperCount == 0)
    }

    @Test("A tap near a label the edge of the dial hides does not zoom there, a tap on a label it shows does")
    func hiddenLabel() async throws {
        let (zoom, interaction) = try await makeInteraction()
        // The end of the range stands 65 degrees off the needle, past the edge where the dial is gone.
        zoom.setZoom(1.69)
        zoom.openDial()
        let upperBound = zoom.scale.range.upperBound
        let hidden = labelCenter(of: upperBound, zoom: zoom)
        let hiddenAngle = zoom.scale.angle(of: upperBound, current: zoom.factor)
        try #require(hiddenAngle > ZoomDialEdgeFade.hiddenAngle && hiddenAngle < .pi / 2)
        let tap = CGPoint(x: hidden.x + 10.7, y: layout.zoomDial.maxY - 4)
        try #require(hypot(tap.x - hidden.x, tap.y - hidden.y) <= CameraMetrics.ZoomDial.labelTapRadius)
        let before = zoom.factor
        interaction.touchChanged(to: tap, from: tap, time: 0, in: layout)
        interaction.touchEnded(at: tap, from: tap, in: layout)
        #expect(zoom.factor == before)
        let shown = labelCenter(of: 4, zoom: zoom)
        interaction.touchChanged(to: shown, from: shown, time: 1, in: layout)
        interaction.touchEnded(at: shown, from: shown, in: layout)
        #expect(zoom.factor == 4)
        interaction.cancelTimers()
    }
}
