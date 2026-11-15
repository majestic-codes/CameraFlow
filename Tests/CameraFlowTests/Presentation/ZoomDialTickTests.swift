//
//  ZoomDialTickTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@Suite("Zoom dial ticks")
struct ZoomDialTickTests {

    @Test("There is a tick every tenth, wider at lenses and marks, whole at whole factors")
    func kinds() {
        let ticks = ZoomDialTick.ticks(range: 0.5...40, emphasizedFactors: [0.5, 1, 1.2, 1.5, 2, 4, 8])
        #expect(ticks.count == 396)
        let tenths = ticks.map { (Int(($0.factor * 10).rounded()), $0.kind) }
        let kinds = Dictionary(tenths) { first, _ in first }
        #expect(kinds.count == ticks.count, "Two ticks stand at the same tenth")
        #expect(kinds[5] == .lens)
        #expect(kinds[6] == .minor)
        #expect(kinds[12] == .lens)
        #expect(kinds[30] == .whole)
        #expect(kinds[80] == .lens)
        #expect(kinds[400] == .whole)
    }
}
