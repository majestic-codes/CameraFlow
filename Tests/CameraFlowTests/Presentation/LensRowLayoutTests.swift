//
//  LensRowLayoutTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

@Suite("Where the lens buttons stand and which one a touch falls on")
struct LensRowLayoutTests {
    private let row = LayoutWindow.referencePhone.layout(panelTileCount: 6)
        .lensRow

    @Test("A touch on the middle of a button falls on its lens, wherever the row has slid", arguments: 0..<5)
    func buttonCenters(activeIndex: Int) {
        let layout = LensRowLayout(row: row, lensCount: 5, activeIndex: activeIndex)
        for index in 0..<5 {
            let center = CGPoint(x: layout.centerX(of: index), y: row.midY)
            #expect(layout.lensIndex(at: center) == index)
        }
        #expect(layout.centerX(of: activeIndex) == row.midX)
    }

    @Test("The touch frame holds every button with the slop of a finger, wherever the row has slid", arguments: 0..<5)
    func touchFrame(activeIndex: Int) {
        let layout = LensRowLayout(row: row, lensCount: 5, activeIndex: activeIndex)
        let radius = CameraMetrics.LensRow.buttonDiameter / 2
        let slop = CameraMetrics.LensRow.touchSlop
        let frame = layout.touchFrame
        #expect(frame.contains(row))
        for index in 0..<5 {
            let center = CGPoint(x: layout.centerX(of: index), y: row.midY)
            let button = CGRect(x: center.x - radius, y: row.minY, width: 2 * radius, height: row.height)
            #expect(frame.contains(button.insetBy(dx: -slop + 0.01, dy: -slop + 0.01)))
        }
    }

    @Test("A touch above or below the row, or past its last button, falls on no lens")
    func outsideTheRow() {
        let layout = LensRowLayout(row: row, lensCount: 3, activeIndex: 1)
        let slop = CameraMetrics.LensRow.touchSlop
        #expect(layout.lensIndex(at: CGPoint(x: row.midX, y: row.minY - slop - 1)) == nil)
        #expect(layout.lensIndex(at: CGPoint(x: row.midX, y: row.maxY + slop + 1)) == nil)
        let pastTheLast = CGPoint(x: layout.centerX(of: 2) + CameraMetrics.LensRow.pitch, y: row.midY)
        #expect(layout.lensIndex(at: pastTheLast) == nil)
        #expect(layout.lensIndex(at: CGPoint(x: row.midX, y: row.minY - slop + 1)) == 1)
    }

    @Test("A row without lenses takes the touches of the row alone")
    func noLenses() {
        let layout = LensRowLayout(row: row, lensCount: 0, activeIndex: 0)
        let slop = CameraMetrics.LensRow.touchSlop
        #expect(layout.touchFrame == row.insetBy(dx: -slop, dy: -slop))
        #expect(layout.lensIndex(at: CGPoint(x: row.midX, y: row.midY)) == nil)
    }
}
