//
//  CameraScreenLayoutTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("Camera screen layout")
struct CameraScreenLayoutTests {
    let layout = LayoutWindow.referencePhone.layout(panelTileCount: 6)

    @Test("The reference screen has the stock frames")
    func referenceFrames() {
        expectClose(layout.viewfinder, CGRect(x: 0, y: 128, width: 402, height: 536))
        expectClose(layout.topBarButton(at: 0, of: 2), CGRect(x: 158.67, y: 67.33, width: 41, height: 41))
        expectClose(layout.topBarButton(at: 1, of: 2), CGRect(x: 202.67, y: 67.33, width: 41, height: 41))
        expectClose(layout.lensRow, CGRect(x: 64, y: 608, width: 274, height: 40))
        expectClose(layout.zoomDial, CGRect(x: 0, y: 536.33, width: 402, height: 127.67))
        expectClose(layout.zoomDialDisc, CGRect(x: -21, y: 536.33, width: 444, height: 444))
        expectClose(layout.shutter, CGRect(x: 161, y: 680, width: 80, height: 80))
        expectClose(layout.more, CGRect(x: 320, y: 696, width: 48, height: 48))
        expectClose(layout.zoomDialCenter.y, 758.33, tolerance: 0.34)
    }

    @Test("The dial disc is one circle whose top is the top of the touch strip, whatever the aspect ratio", arguments: [
        CameraFlowAspectRatio.fourByThree, .sixteenByNine, .square
    ])
    func dialDisc(aspectRatio: CameraFlowAspectRatio) {
        let layout = LayoutWindow.referencePhone.layout(aspectRatio: aspectRatio, panelTileCount: 6)
        let disc = layout.zoomDialDisc
        #expect(disc.width == disc.height)
        expectClose(disc.width, CameraMetrics.ZoomDial.radius * 2, tolerance: 0.01)
        expectClose(disc.minY, layout.zoomDial.minY, tolerance: 0.01)
        expectClose(disc.midX, layout.zoomDialCenter.x, tolerance: 0.01)
        expectClose(disc.midY, layout.zoomDialCenter.y, tolerance: 0.01)
    }

    @Test("The viewfinder follows the aspect ratio", arguments: [
        (CameraFlowAspectRatio.fourByThree, 128.0, 536.0),
        (CameraFlowAspectRatio.sixteenByNine, 61.33, 714.67),
        (CameraFlowAspectRatio.square, 179.0, 402.0)
    ])
    func aspectRatios(aspectRatio: CameraFlowAspectRatio, top: Double, height: Double) {
        let layout = LayoutWindow.referencePhone.layout(aspectRatio: aspectRatio, panelTileCount: 6)
        expectClose(layout.viewfinder, CGRect(x: 0, y: top, width: 402, height: height))
        expectClose(layout.lensRow, CGRect(x: 64, y: 608, width: 274, height: 40))
    }

    @Test("The control panel is the stock three-row card less one row, with the stock lower rows")
    func controlPanel() {
        let layout = LayoutWindow.referencePhone.layout(panel: .tiles, panelTileCount: 6)
        expectClose(layout.controlPanel, CGRect(x: 8, y: 549.67, width: 386, height: 316))
        let first = layout.controlPanelTileCircleCenter(at: 0)
        let last = layout.controlPanelTileCircleCenter(at: 5)
        expectClose(first.x, 85.67, tolerance: 0.34)
        expectClose(first.y, 633.67, tolerance: 0.34)
        expectClose(last.x, 316.33, tolerance: 0.34)
        expectClose(last.y, 757.67, tolerance: 0.34)
        expectClose(layout.controlPanelGrabber.minY, 559.67, tolerance: 0.34)
        expectClose(layout.panelCard, layout.controlPanel)
    }

    @Test("The tile cells and the grabber lie inside the control panel card")
    func controlPanelTiles() {
        let layout = LayoutWindow.referencePhone.layout(panel: .tiles, panelTileCount: 6)
        expectClose(layout.controlPanelTile(at: 0), CGRect(x: 25.33, y: 599.67, width: 120.67, height: 94))
        expectClose(layout.controlPanelTile(at: 4), CGRect(x: 140.67, y: 723.67, width: 120.67, height: 94))
        for index in 0..<layout.panelTileCount {
            #expect(layout.controlPanel.contains(layout.controlPanelTile(at: index)))
        }
        #expect(layout.controlPanel.contains(layout.controlPanelGrabber))
        expectClose(layout.controlPanelGrabber.midX, layout.controlPanel.midX, tolerance: 0.01)
    }

    @Test("Five tiles keep the two rows of the card and fill the grid row by row")
    func controlPanelWithFiveTiles() {
        let layout = LayoutWindow.referencePhone.layout(panel: .tiles, panelTileCount: 5)
        expectClose(layout.controlPanel, CGRect(x: 8, y: 549.67, width: 386, height: 316))
        let last = layout.controlPanelTileCircleCenter(at: 4)
        expectClose(last.x, 201, tolerance: 0.34)
        expectClose(last.y, 757.67, tolerance: 0.34)
        for index in 0..<layout.panelTileCount {
            #expect(layout.controlPanel.contains(layout.controlPanelTile(at: index)))
        }
    }

    @Test("The card has as many rows as its tiles fill", arguments: [(3, 192.0), (4, 316.0), (6, 316.0), (7, 440.0)])
    func controlPanelRows(tileCount: Int, height: Double) {
        let layout = LayoutWindow.referencePhone.layout(panel: .tiles, panelTileCount: tileCount)
        expectClose(layout.controlPanel.height, height, tolerance: 0.34)
        expectClose(layout.controlPanel.maxY, 865.67, tolerance: 0.34)
    }

    @Test("A lone top bar indicator stands in the centre")
    func loneTopBarButton() {
        expectClose(layout.topBarButton(at: 0, of: 1), CGRect(x: 180.5, y: 67.33, width: 41, height: 41))
    }

    @Test("The top bar strip is centred and keeps a slot's gap from the flip button", arguments: [
        CGSize(width: 402, height: 874),
        CGSize(width: 375, height: 667),
        CGSize(width: 440, height: 956)
    ])
    func topBarViewport(size: CGSize) {
        let layout = CameraScreenLayout(size: size, safeAreaTop: 62, panelTileCount: 6)
        let viewport = layout.topBarViewport
        let gap = CameraMetrics.TopBar.pitch - CameraMetrics.TopBar.buttonSize
        expectClose(viewport.midX, size.width / 2, tolerance: 0.01)
        expectClose(viewport.maxX + gap, layout.flip.minX, tolerance: 0.01)
        #expect(viewport.minY == layout.topBarButton(at: 0, of: 1).minY)
        #expect(viewport.height == CameraMetrics.TopBar.buttonSize)
    }

    @Test("The top bar scrolls once its items are wider than the strip", arguments: [
        (CGSize(width: 402, height: 874), 6),
        (CGSize(width: 375, height: 667), 5),
        (CGSize(width: 440, height: 956), 7)
    ])
    func topBarOverflow(size: CGSize, fittingCount: Int) {
        let layout = CameraScreenLayout(size: size, safeAreaTop: 62, panelTileCount: 6)
        #expect(layout.topBarOverflows(itemCount: 0) == false)
        #expect(layout.topBarOverflows(itemCount: 1) == false)
        #expect(layout.topBarOverflows(itemCount: fittingCount) == false)
        #expect(layout.topBarOverflows(itemCount: fittingCount + 1))
        let last = layout.topBarButton(at: fittingCount - 1, of: fittingCount)
        #expect(last.maxX <= layout.topBarViewport.maxX + 0.01)
    }

    @Test("A row is as wide as its items at the pitch of the slots", arguments: [
        (0, 0.0),
        (1, 41.0),
        (2, 85.0),
        (6, 261.0)
    ])
    func topBarContentWidth(itemCount: Int, width: Double) {
        #expect(Double(layout.topBarContentWidth(itemCount: itemCount)) == width)
    }

    @Test("The closed card is a blob around the shutter that the panel grows from")
    func closedCard() {
        expectClose(layout.panelCard.midX, layout.shutter.midX, tolerance: 0.01)
        expectClose(layout.panelCard.midY, layout.shutter.midY, tolerance: 0.01)
    }

    @Test("An open sub-panel lifts the lens row, the dial and the shutter")
    func subPanel() {
        let layout = LayoutWindow.referencePhone.layout(panel: .subPanel(.flash), panelTileCount: 6)
        expectClose(layout.subPanel, CGRect(x: 8, y: 682.33, width: 386, height: 183.67))
        expectClose(layout.panelCard, layout.subPanel)
        expectClose(layout.shutter.midY, 618, tolerance: 0.34)
        expectClose(layout.lensRow.midY, 526, tolerance: 0.34)
        expectClose(layout.subPanelBackButton.midX, 50.67, tolerance: 0.34)
        expectClose(layout.subPanelBackButton.midY, 724.67, tolerance: 0.34)
        expectClose(layout.viewfinder, CGRect(x: 0, y: 128, width: 402, height: 536))
    }

    @Test("With a sub-panel open the dial rises with the lens row and reaches down to the bottom of the viewfinder")
    func dialOverSubPanel() {
        let layout = LayoutWindow.referencePhone.layout(panel: .subPanel(.format), panelTileCount: 6)
        expectClose(layout.zoomDial, CGRect(x: 0, y: 434.33, width: 402, height: 229.67))
        expectClose(layout.zoomDialDisc, CGRect(x: -21, y: 434.33, width: 444, height: 444))
        expectClose(layout.zoomDialCenter.y, 656.33, tolerance: 0.34)
        expectClose(layout.zoomDial.maxY, layout.viewfinder.maxY, tolerance: 0.01)
        #expect(layout.zoomDial.contains(layout.shutter))
    }

    @Test("The grid of tiles hides the zoom control, a sub-panel and the closed panel show it", arguments: [
        (CameraPanelPresentation.hidden, true),
        (CameraPanelPresentation.tiles, false),
        (CameraPanelPresentation.subPanel(.format), true)
    ])
    func zoomControlVisibility(panel: CameraPanelPresentation, isShown: Bool) {
        let layout = LayoutWindow.referencePhone.layout(panel: panel, panelTileCount: 6)
        #expect(layout.showsZoomControl == isShown)
    }

    @Test("A short screen keeps the whole viewfinder and hangs the lens row above the controls")
    func shortScreen() {
        let layout = CameraScreenLayout(size: CGSize(width: 375, height: 667), safeAreaTop: 20, panelTileCount: 6)
        #expect(layout.viewfinder.height == 500)
        #expect(layout.viewfinder.minY >= 0)
        #expect(layout.viewfinder.maxY <= 667)
        #expect(layout.lensRow.maxY <= 667 - 210)
        #expect(layout.shutter.midX == 187.5)
    }
}
