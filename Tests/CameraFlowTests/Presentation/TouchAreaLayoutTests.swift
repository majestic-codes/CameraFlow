//
//  TouchAreaLayoutTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@_spi(Testing) @testable import CameraFlow

/// The camera's controls that are drawn smaller than a finger needs take a touch in a larger area around the same
/// centre, and the drawn controls keep the stock places and sizes.
@Suite("Touch areas of the small camera controls")
struct TouchAreaLayoutTests {
    /// The least side of a touch area the Human Interface Guidelines ask for.
    private static let minimumTouchSide: CGFloat = 44

    @Test(
        "A top bar item takes a touch in a square around its button, beside its neighbours and inside the strip",
        arguments: LayoutWindow.all
    )
    func topBarItems(window: LayoutWindow) throws {
        let layout = window.layout()
        let strip = layout.topBarTouchStrip
        let counts = 1...CameraSetting.allCases.count
        let count = try #require(counts.last { !layout.topBarOverflows(itemCount: $0) })
        let side = CameraMetrics.TopBar.touchSize
        #expect(side >= Self.minimumTouchSide)
        var areas: [CGRect] = []
        for index in 0..<count {
            let button = layout.topBarButton(at: index, of: count)
            let area = CameraScreenLayout.square(side, center: CGPoint(x: button.midX, y: button.midY))
            #expect(area.contains(button), "item \(index) of \(count)")
            #expect(strip.insetBy(dx: -0.01, dy: -0.01).contains(area), "item \(index) of \(count)")
            areas.append(area)
        }
        for (area, next) in zip(areas, areas.dropFirst()) {
            #expect(area.maxX <= next.minX + 0.01)
        }
    }

    @Test(
        "The strip of the top bar holds the drawn strip and keeps to the line of the top bar",
        arguments: LayoutWindow.all
    )
    func topBarStrip(window: LayoutWindow) {
        let layout = window.layout()
        let strip = layout.topBarTouchStrip
        let slot = layout.topBarButton(at: 0, of: 1)
        #expect(strip.contains(layout.topBarViewport))
        #expect(strip.height == CameraMetrics.TopBar.touchSize)
        expectClose(strip.midY, slot.midY, tolerance: 0.01)
        expectClose(strip.midX, layout.topBarViewport.midX, tolerance: 0.01)
        #expect(strip.maxX <= layout.flip.minX)
        #expect(strip.maxY <= layout.topLineBottom + 0.01)
    }

    @Test(
        "Back takes a touch in a larger circle around its own, clear of the texts and the options",
        arguments: LayoutWindow.all
    )
    func subPanelBack(window: LayoutWindow) {
        let layout = window.layout(panel: .subPanel(.timer))
        let metrics = CameraMetrics.SubPanel.self
        let button = layout.subPanelBackButton
        let area = layout.subPanelBackTouchArea
        #expect(button.width == metrics.backButtonDiameter)
        #expect(area.width >= Self.minimumTouchSide)
        #expect(area.height == area.width)
        expectClose(area.midX, button.midX, tolerance: 0.01)
        expectClose(area.midY, button.midY, tolerance: 0.01)
        #expect(layout.subPanel.contains(area))
        let title = layout.subPanelTextLine(centeredAt: metrics.titleCenter, height: metrics.titleHeight)
        let value = layout.subPanelTextLine(centeredAt: metrics.valueCenter, height: metrics.valueHeight)
        #expect(area.maxX <= title.minX + 0.01)
        #expect(area.maxX <= value.minX + 0.01)
        let optionsTop = layout.subPanel.minY + metrics.optionCenterY - metrics.optionHitHeight / 2
        #expect(area.maxY <= optionsTop)
    }
}
