//
//  SubPanelRulerScaleTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@Suite("Exposure ruler scale")
struct SubPanelRulerScaleTests {

    @Test("ticks near the centre are fully visible and the far ones fade out")
    func fade() {
        #expect(SubPanelRulerScale.fade(atDistance: 0) == 1)
        #expect(SubPanelRulerScale.fade(atDistance: 3) == 1)
        expectClose(SubPanelRulerScale.fade(atDistance: 4), 0.35, tolerance: 0.001)
        #expect(SubPanelRulerScale.fade(atDistance: 5) == 0)
    }

    @Test("dragging right lowers the bias by a third of a stop per tick pitch")
    func dragDirection() {
        let lowered = SubPanelRulerScale.bias(from: 0, translation: 20)
        expectClose(lowered, -1.0 / 3.0, tolerance: 0.0001)
        #expect(SubPanelRulerScale.bias(from: 0.5, translation: -60) > 0.5)
    }

    @Test(
        "The ruler ticks cover the bias range, a tick per third of a stop",
        arguments: [(-2.0...2.0, -6...6), (-1.0...1.5, -3...4), (-0.2...0.2, 0...0)]
    )
    func rulerTicks(range: ClosedRange<Double>, indices: ClosedRange<Int>) {
        #expect(SubPanelRulerScale.tickIndices(in: range) == indices)
    }
}
