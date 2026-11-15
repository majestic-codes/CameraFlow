//
//  InterfaceQuarterTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("The quarter of the interface and the hold of the device")
struct InterfaceQuarterTests {

    @Test(
        "An interface turned to one side has the top of the device on the other",
        arguments: [
            (InterfaceQuarter.portrait, CameraOrientation.portrait),
            (.portraitUpsideDown, .upsideDown),
            (.landscapeLeft, .landscapeRight),
            (.landscapeRight, .landscapeLeft)
        ]
    )
    func deviceOrientation(quarter: InterfaceQuarter, orientation: CameraOrientation) {
        #expect(quarter.deviceOrientation == orientation)
    }

    @Test("Every quarter of the interface is a different hold of the device")
    func distinctHolds() {
        let holds = InterfaceQuarter.allCases.map(\.deviceOrientation)
        #expect(Set(holds.map { "\($0)" }).count == InterfaceQuarter.allCases.count)
    }
}
