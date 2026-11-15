//
//  DualCameraLayoutTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

/// The front camera's circle and its toggle on the 402 x 874 screen of the approved mock-up.
@Suite("Dual camera layout")
struct DualCameraLayoutTests {

    private func layout(_ aspectRatio: CameraFlowAspectRatio) -> CameraScreenLayout {
        LayoutWindow.referencePhone.layout(aspectRatio: aspectRatio, panelTileCount: 6)
    }

    @Test(
        "The circle is a third of the viewfinder wide, 12 pt inside its top trailing corner and below the flip button",
        arguments: [
            (CameraFlowAspectRatio.fourByThree, CGRect(x: 257, y: 140, width: 133, height: 133)),
            (.sixteenByNine, CGRect(x: 257, y: 121.833, width: 133, height: 133)),
            (.square, CGRect(x: 257, y: 191, width: 133, height: 133))
        ]
    )
    func circle(aspectRatio: CameraFlowAspectRatio, expected: CGRect) {
        let layout = layout(aspectRatio)
        let circle = layout.dualCameraCircle
        expectClose(circle, expected)
        #expect(layout.viewfinder.contains(circle))
        #expect(circle.intersects(layout.flip) == false)
        #expect(circle.minY - layout.flip.maxY >= FlowMetrics.DualCameraCircle.margin)
        #expect(circle.maxY < layout.lensRow.minY)
    }

    @Test("The place of the circle is its square in unit coordinates of the viewfinder, the rim and shadow in shares")
    func placement() throws {
        let layout = layout(.fourByThree)
        let placement = try #require(layout.dualCameraCirclePlacement)
        let viewfinder = layout.viewfinder
        let region = placement.region
        let circle = layout.dualCameraCircle
        let back = CGRect(
            x: viewfinder.minX + region.minX * viewfinder.width,
            y: viewfinder.minY + region.minY * viewfinder.height,
            width: region.width * viewfinder.width,
            height: region.height * viewfinder.height
        )
        expectClose(back, circle)
        expectClose(placement.rimWidthRatio, 1.5 / 133, tolerance: 0.0001)
        expectClose(placement.shadowRadiusRatio, 8 / 133, tolerance: 0.0001)
        #expect(placement.rimOpacity == FlowMetrics.DualCameraCircle.rimOpacity)
    }

    @Test("Four indicators are centred together at the pitch of the stock top bar and keep clear of the flip")
    func fourIndicators() {
        let layout = layout(.fourByThree)
        let frames = (0..<4).map { layout.topBarButton(at: $0, of: 4) }
        expectClose(frames[0], CGRect(x: 114.5, y: 67.333, width: 41, height: 41))
        expectClose(frames[1], CGRect(x: 158.5, y: 67.333, width: 41, height: 41))
        expectClose(frames[2], CGRect(x: 202.5, y: 67.333, width: 41, height: 41))
        expectClose(frames[3], CGRect(x: 246.5, y: 67.333, width: 41, height: 41))
        #expect(frames[3].maxX < layout.flip.minX)
    }

    @Test("The notice keeps its row across the viewfinder, and moves below the circle while it shows")
    func notice() {
        let layout = layout(.fourByThree)
        #expect(layout.notice(isDualCameraCircleShown: false) == layout.notice)
        let shown = layout.notice(isDualCameraCircleShown: true)
        expectClose(shown, CGRect(x: 0, y: 285, width: 402, height: 30))
        #expect(shown.intersects(layout.dualCameraCircle) == false)
    }
}
