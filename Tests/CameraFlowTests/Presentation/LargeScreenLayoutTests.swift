//
//  LargeScreenLayoutTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("Camera layout on larger screens")
struct LargeScreenLayoutTests {
    private let tolerance: CGFloat = 0.01

    private func expectInside(
        _ frame: CGRect,
        _ bounds: CGRect,
        _ what: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let isInside = bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(frame)
        #expect(isInside, "\(what) \(frame) leaves \(bounds)", sourceLocation: sourceLocation)
    }

    @Test("A phone lays the camera out across its whole width", arguments: LayoutWindow.phones)
    func phoneColumn(window: LayoutWindow) {
        let layout = window.layout()
        #expect(layout.column == window.bounds)
        #expect(layout.controlsBand == window.bounds)
        #expect(layout.viewfinder.minX == 0)
        #expect(layout.viewfinder.width == window.size.width)
    }

    @Test("A large screen lays the camera out in a column in its middle", arguments: LayoutWindow.iPads)
    func column(window: LayoutWindow) {
        let layout = window.layout()
        let column = layout.column
        let topBarBottom = layout.topBarButton(at: 0, of: 1).maxY
        let heightPerWidth: CGFloat = window.isLandscape ? 3.0 / 4 : 4.0 / 3
        let largestWidth = (window.size.height - topBarBottom) / heightPerWidth
        expectClose(column.midX, window.size.width / 2, tolerance: tolerance)
        #expect(column.width <= window.size.width)
        #expect(column.width >= min(window.size.width, CameraMetrics.Column.phoneWidth, largestWidth) - tolerance)
        #expect(layout.controlsBand.width <= CameraMetrics.Column.phoneWidth)
        expectClose(layout.controlsBand.midX, column.midX, tolerance: tolerance)
        expectInside(layout.standardViewfinder, column, "the 4:3 viewfinder")
    }

    @Test("The column of a large screen is as wide as the arrangement fits its height", arguments: [
        (CGSize(width: 1032, height: 1376), CameraOrientation.portrait),
        (CGSize(width: 1376, height: 1032), CameraOrientation.landscapeLeft),
        (CGSize(width: 834, height: 1210), CameraOrientation.portrait),
        (CGSize(width: 1210, height: 834), CameraOrientation.landscapeRight)
    ])
    func columnFitsTheHeight(size: CGSize, orientation: CameraOrientation) {
        let window = LayoutWindow(name: "iPad", size: size, safeAreaTop: 24, interfaceOrientation: orientation)
        let layout = window.layout()
        let viewfinder = layout.standardViewfinder
        let topBarBottom = layout.topBarButton(at: 0, of: 1).maxY
        expectClose(viewfinder.minY, topBarBottom, tolerance: tolerance)
        expectClose(viewfinder.maxY + CameraMetrics.Viewfinder.controlsHeight, size.height, tolerance: tolerance)
        expectClose(viewfinder.width, layout.column.width, tolerance: tolerance)
    }

    @Test(
        "The viewfinder has the shape of the picture: portrait in a portrait interface, landscape in landscape",
        arguments: LayoutWindow.all, [CameraFlowAspectRatio.fourByThree, .sixteenByNine, .square]
    )
    func viewfinderShape(window: LayoutWindow, aspectRatio: CameraFlowAspectRatio) {
        let isLandscape = window.isLandscape
        let viewfinder = window.layout(aspectRatio: aspectRatio).viewfinder
        let ratio = isLandscape ? 1 / aspectRatio.heightPerWidth : aspectRatio.heightPerWidth
        expectClose(viewfinder.height / viewfinder.width, ratio, tolerance: 0.001, "\(aspectRatio)")
        expectInside(viewfinder, window.bounds, "the \(aspectRatio) viewfinder")
    }

    @Test(
        "Every control stays on the screen and in the column",
        arguments: LayoutWindow.all, [CameraPanelPresentation.hidden, .tiles, .subPanel(.format)]
    )
    func controlsOnScreen(window: LayoutWindow, panel: CameraPanelPresentation) {
        let layout = window.layout(panel: panel)
        let column = layout.column
        let tiles = (0..<layout.panelTileCount).map { ("tile \($0)", layout.controlPanelTile(at: $0)) }
        let frames = [
            ("shutter", layout.shutter), ("library", layout.library), ("more", layout.more),
            ("exit", layout.exit), ("accept", layout.accept), ("mode switch", layout.modeSwitch),
            ("lens row", layout.lensRow), ("flip", layout.flip), ("top bar", layout.topBarViewport),
            ("zoom dial", layout.zoomDial), ("panel card", layout.panelCard), ("trash", layout.reviewTrash),
            ("markup", layout.reviewMarkup), ("review strip", layout.reviewStrip(isRightToLeft: false).frame),
            ("reviewed photo", layout.reviewedPhoto), ("sub-panel back", layout.subPanelBackButton),
            ("notice", layout.notice), ("circle", layout.dualCameraCircle)
        ] + tiles
        for (name, frame) in frames {
            expectInside(frame, window.bounds, name)
            expectInside(frame, column, name)
        }
        #expect(layout.exit.maxX < layout.modeSwitch.minX)
        #expect(layout.modeSwitch.maxX < layout.accept.minX)
        #expect(layout.library.maxX < layout.shutter.minX)
        #expect(layout.shutter.maxX < layout.more.minX)
    }

    @Test("The controls of a large screen keep the width of the widest phone", arguments: LayoutWindow.iPads)
    func controlsWidth(window: LayoutWindow) {
        let layout = window.layout()
        guard layout.column.width >= CameraMetrics.Column.phoneWidth else {
            #expect(layout.controlsBand == layout.column)
            return
        }
        let phone = LayoutWindow.phones[5].layout()
        expectClose(layout.modeSwitch.width, phone.modeSwitch.width, tolerance: tolerance)
        expectClose(layout.accept.minX - layout.exit.minX, phone.accept.minX - phone.exit.minX, tolerance: tolerance)
        expectClose(window.layout(panel: .tiles).controlPanel.width, phone.controlPanel.width, tolerance: tolerance)
    }
}

@Suite("Camera layout in windows of every shape")
struct WindowShapeLayoutTests {
    private let tolerance: CGFloat = 0.01

    @Test("Every tile lies in the card, its circle apart from its neighbours', its row above the next one",
          arguments: LayoutWindow.all)
    func tilesInTheCard(window: LayoutWindow) {
        let layout = window.layout(panel: .tiles)
        let metrics = CameraMetrics.ControlPanel.self
        let card = layout.controlPanel.insetBy(dx: -tolerance, dy: -tolerance)
        let tiles = (0..<layout.panelTileCount).map(layout.controlPanelTile(at:))
        let diameter = metrics.tileCircleDiameter * layout.controlPanelScale
        for (index, tile) in tiles.enumerated() {
            #expect(card.contains(tile), "tile \(index) \(tile) leaves the card \(card)")
            if index % metrics.columns > 0 {
                let distance = layout.controlPanelTileCircleCenter(at: index).x
                    - layout.controlPanelTileCircleCenter(at: index - 1).x
                #expect(distance >= diameter, "the circle of tile \(index) touches its neighbour's")
            }
            if index >= metrics.columns {
                let above = tiles[index - metrics.columns]
                #expect(above.maxY <= tile.minY + tolerance, "tile \(index) under the row above")
            }
        }
        #expect(card.contains(layout.controlPanelGrabber))
        #expect(layout.controlPanelGrabberTouchArea.intersects(layout.controlPanelTile(at: 0)) == false)
        #expect(layout.controlPanel.minY >= layout.topLineBottom - tolerance)
    }

    @Test("A tile label keeps apart from its neighbour's and inside the card", arguments: LayoutWindow.all)
    func tileLabels(window: LayoutWindow) {
        let layout = window.layout(panel: .tiles)
        let metrics = CameraMetrics.ControlPanel.self
        let width = layout.controlPanelTileLabelWidth * layout.controlPanelScale
        let spacing = metrics.labelSpacing * layout.controlPanelScale
        #expect(width > 0)
        #expect(width + spacing <= layout.controlPanelColumnPitch + tolerance)
        let leftmost = layout.controlPanelTileCircleCenter(at: 0).x - width / 2
        let rightmost = layout.controlPanelTileCircleCenter(at: metrics.columns - 1).x + width / 2
        #expect(leftmost >= layout.controlPanel.minX + spacing - tolerance)
        #expect(rightmost <= layout.controlPanel.maxX - spacing + tolerance)
    }

    @Test("A phone has the stock grid: the stock pitch, at full size", arguments: LayoutWindow.phones)
    func stockGrid(window: LayoutWindow) {
        let layout = window.layout(panel: .tiles)
        #expect(layout.controlPanelScale == 1)
        #expect(layout.controlPanelColumnPitch == CameraMetrics.ControlPanel.columnPitch)
    }

    @Test("A window shorter than the stock card shrinks the grid to fit below the top bar",
          arguments: LayoutWindow.shortWindows)
    func shortWindow(window: LayoutWindow) {
        let layout = window.layout(panel: .tiles)
        let room = window.size.height - CameraMetrics.ControlPanel.bottomInset - layout.topLineBottom
        #expect(layout.controlPanelScale < 1)
        expectClose(layout.controlPanel.height, room, tolerance: tolerance)
        expectClose(layout.controlPanel.minY, layout.topLineBottom, tolerance: tolerance)
    }

    @Test("A window too short for the stock arrangement keeps the 4:3 page whole between the top bar and its bottom",
          arguments: LayoutWindow.shortWindows)
    func shortWindowViewfinder(window: LayoutWindow) {
        let layout = window.layout()
        let topBarBottom = layout.topBarButton(at: 0, of: 1).maxY
        #expect(layout.reviewedPhoto.minY >= topBarBottom - tolerance)
        #expect(layout.reviewedPhoto.maxY <= window.size.height + tolerance)
    }

    @Test("A sub-panel lifts the dial no higher than the line of the top bar", arguments: LayoutWindow.all)
    func liftedDial(window: LayoutWindow) {
        let layout = window.layout(panel: .subPanel(.format))
        #expect(layout.zoomDial.minY >= layout.topLineBottom - tolerance)
    }

    @Test("A phone keeps the viewfinder standing on the controls, with the free height above it",
          arguments: LayoutWindow.phones)
    func phoneViewfinder(window: LayoutWindow) {
        let layout = window.layout()
        let viewfinder = layout.standardViewfinder
        let controlsTop = window.size.height - CameraMetrics.Viewfinder.controlsHeight
        let topBarBottom = layout.topBarButton(at: 0, of: 1).maxY
        let isShort = controlsTop - viewfinder.height < topBarBottom
        #expect(isShort || isClose(viewfinder.maxY, to: controlsTop, tolerance: tolerance))
    }

    @Test("A tall narrow window stands the viewfinder in the middle of its free height, past the gap of the phones",
          arguments: LayoutWindow.iPads.filter { $0.size.height > 2 * $0.size.width })
    func tallWindow(window: LayoutWindow) {
        let layout = window.layout()
        let viewfinder = layout.standardViewfinder
        let gapAbove = viewfinder.minY - layout.topBarButton(at: 0, of: 1).maxY
        let gapBelow = window.size.height - CameraMetrics.Viewfinder.controlsHeight - viewfinder.maxY
        #expect(gapBelow > 0)
        expectClose(gapAbove - gapBelow, CameraMetrics.Viewfinder.largestGapAbove, tolerance: tolerance)
        #expect(layout.lensRow.maxY <= viewfinder.maxY)
    }

    @Test(
        "A notice keeps below the line of the top bar and its corner buttons, in every window and aspect ratio",
        arguments: LayoutWindow.all
    )
    func noticeBelowTheTopBar(window: LayoutWindow) {
        for aspectRatio in CameraFlowAspectRatio.allCases {
            let layout = window.layout(aspectRatio: aspectRatio)
            let topLine = [
                layout.topBarButton(at: 0, of: 1), layout.flip, layout.reviewTrash, layout.reviewMarkup,
                layout.reviewCounter
            ]
            for notice in [layout.notice, layout.notice(isDualCameraCircleShown: true)] {
                for frame in topLine {
                    #expect(notice.minY >= frame.maxY, "\(aspectRatio): \(notice) under \(frame)")
                }
                #expect(notice.minY >= layout.viewfinder.minY)
            }
        }
    }
}
