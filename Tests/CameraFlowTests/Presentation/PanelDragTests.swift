//
//  PanelDragTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

@Suite("The drag of the control panel's grabber and the rubber band past an end")
struct PanelDragTests {
    private typealias Metrics = CameraMetrics.ControlPanel

    @Test("The card follows a finger down one to one", arguments: [0, 10, 59, 300] as [CGFloat])
    func followsDown(translation: CGFloat) {
        #expect(ControlPanelDrag.offset(forTranslation: translation) == translation)
    }

    @Test("The card gives way to an upward pull less and less, and never past the limit")
    func resistsUp() {
        let offsets = ([-1, -10, -48, -200, -10_000] as [CGFloat]).map(ControlPanelDrag.offset(forTranslation:))
        #expect(zip(offsets, offsets.dropFirst()).allSatisfy { $0 > $1 })
        #expect(offsets.allSatisfy { $0 < 0 && $0 > -Metrics.dragResistanceLimit })
        // A pull of twice the limit at half stiffness takes the card half the limit up.
        expectClose(offsets[2], -Metrics.dragResistanceLimit / 2, tolerance: 0.0001)
    }

    @Test(
        "A drag far enough or flung fast enough closes the panel",
        arguments: [(30.0, 100.0, false), (61.0, 61.0, true), (20.0, 141.0, true), (60.0, 140.0, false)]
    )
    func dismisses(translation: Double, predicted: Double, closes: Bool) {
        #expect(ControlPanelDrag.dismisses(translation: translation, predictedTranslation: predicted) == closes)
    }

    @Test("The rubber band gives nothing for no pull, and nothing with no limit")
    func rubberBandEnds() {
        let band = RubberBand(limit: 12, stiffness: 0.55)
        #expect(band.offset(forOvershoot: 0) == 0)
        #expect(band.offset(forOvershoot: -5) == 0)
        #expect(RubberBand(limit: 0, stiffness: 0.5).offset(forOvershoot: 40) == 0)
        #expect(band.offset(forOvershoot: 1_000_000) < 12)
    }

    @Test("The mode switch gives way past its ends with the same rubber band, at its own limit and stiffness")
    func modeSwitchBand() {
        let metrics = FlowMetrics.ModeSwitch.self
        let band = RubberBand(limit: metrics.rubberBandLimit, stiffness: metrics.rubberBandStiffness)
        for overshoot in [1, 20, 300] as [CGFloat] {
            #expect(ModeSwitchTracking.band(overshoot) == band.offset(forOvershoot: overshoot))
        }
    }
}
