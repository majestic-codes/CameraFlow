//
//  CameraScreenLayoutPanelTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("Camera screen layout: the countdown and the cards of the control panel")
struct CameraScreenLayoutPanelTests {

    private func makeLayout(
        aspectRatio: CameraFlowAspectRatio = .fourByThree,
        panel: CameraPanelPresentation = .hidden
    ) -> CameraScreenLayout {
        LayoutWindow.referencePhone.layout(aspectRatio: aspectRatio, panel: panel, panelTileCount: 6)
    }

    @Test(
        "The self-timer digits are centred in the viewfinder of every aspect ratio",
        arguments: CameraFlowAspectRatio.allCases
    )
    func countdown(aspectRatio: CameraFlowAspectRatio) {
        let layout = makeLayout(aspectRatio: aspectRatio)
        #expect(layout.countdown == layout.viewfinder)
        #expect(layout.countdown.midX == LayoutWindow.referencePhone.size.width / 2)
    }

    @Test("The strip that takes the drag of the grabber runs along the top of the card and holds the grabber")
    func grabberTouchArea() {
        let layout = makeLayout(panel: .tiles)
        let card = layout.controlPanel
        let strip = layout.controlPanelGrabberTouchArea
        #expect(strip.minX == card.minX)
        #expect(strip.minY == card.minY)
        #expect(strip.width == card.width)
        #expect(strip.height == CameraMetrics.ControlPanel.grabberTouchHeight)
        #expect(strip.contains(layout.controlPanelGrabber))
        #expect(card.contains(strip))
        #expect(strip.intersects(layout.controlPanelTile(at: 0)) == false)
    }

    @Test("A line of text of the sub-panel is centred on the card, clear of the back button, at its offset")
    func subPanelTextLine() {
        let layout = makeLayout(panel: .subPanel(.flash))
        let card = layout.subPanel
        let line = layout.subPanelTextLine(centeredAt: 30, height: 14)
        expectClose(line.midX, card.midX, tolerance: 0.01)
        #expect(line.minX - layout.subPanelBackButton.maxX >= CameraMetrics.SubPanel.textSpacing - 0.01)
        #expect(card.contains(line))
        #expect(line.height == 14)
        #expect(line.midY == card.minY + 30)
    }
}
