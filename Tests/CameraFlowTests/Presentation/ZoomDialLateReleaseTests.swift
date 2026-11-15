//
//  ZoomDialLateReleaseTests.swift
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
@Suite("A press on the lens row that lifts as the dial is due to open", .timeLimit(.minutes(1)))
struct ZoomDialLateReleaseTests {

    @Test("A press that lifts once the open delay ended, before the dial opened, selects the lens and keeps it closed")
    func liftAsOpenDelayEnds() async throws {
        let service = RecordingCameraService()
        let clock = ManualClock()
        let layout = LayoutWindow.referencePhone.layout(panelTileCount: 6)
        let zoom = try await makeStartedZoom(service: service)
        let interaction = ZoomDialInteraction(zoom: zoom, clock: clock)
        let row = layout.lensRow
        let telephoto = CGPoint(x: row.midX + 2 * CameraMetrics.LensRow.pitch, y: row.midY)
        interaction.touchChanged(to: telephoto, from: telephoto, time: 0, in: layout)
        await clock.waitForSleepers()
        clock.advance(by: CameraMetrics.ZoomDial.openDelay)
        interaction.touchEnded(at: telephoto, from: telephoto, in: layout)
        await settleQueuedWork()
        #expect(zoom.isDialOpen == false)
        #expect(zoom.factor == 4)
    }
}
