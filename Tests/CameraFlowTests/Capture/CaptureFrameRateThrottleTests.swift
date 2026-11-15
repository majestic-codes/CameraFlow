//
//  CaptureFrameRateThrottleTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@Suite("Frame rate under system pressure")
struct CaptureFrameRateThrottleTests {
    /// A pressure, the frame rate ranges of a format and the rates the camera runs at, nil for the format's own.
    struct Row: Sendable, CustomTestStringConvertible {
        let name: String
        let pressure: CaptureSystemPressure
        let supported: [ClosedRange<Double>]
        let rates: ClosedRange<Double>?

        var testDescription: String {
            name
        }
    }

    static let rows = [
        Row(name: "low pressure keeps the format's rates", pressure: .low, supported: [1...60], rates: nil),
        Row(name: "serious pressure slows the camera", pressure: .serious, supported: [1...60], rates: 15...20),
        Row(name: "critical pressure slows the camera", pressure: .critical, supported: [1...30], rates: 15...20),
        Row(
            name: "a format that holds the rates in one of its ranges is slowed",
            pressure: .serious,
            supported: [60...120, 3...30],
            rates: 15...20
        ),
        Row(
            name: "a format that cannot run that slow keeps its rates",
            pressure: .serious,
            supported: [24...60],
            rates: nil
        ),
        Row(
            name: "a format whose ranges hold the rates only together keeps its rates",
            pressure: .critical,
            supported: [1...16, 16...60],
            rates: nil
        )
    ]

    @Test("A camera runs slower from the serious level on, where its format can", arguments: rows)
    func frameRates(row: Row) {
        #expect(CaptureFrameRateThrottle.frameRates(under: row.pressure, supported: row.supported) == row.rates)
    }
}
