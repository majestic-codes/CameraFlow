//
//  FlowLayoutTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

/// The frames of the flow's own controls on the 402 x 874 screen of the approved mock-up (`mock.js`).
@Suite("Flow layout")
struct FlowLayoutTests {
    let layout = LayoutWindow.referencePhone.layout(panelTileCount: 5)

    /// The label widths the mock-up draws its Ukrainian segments for: 96 and 116 pt in the 212 pt of both pills.
    static let mockLabelWidths = ModeLabelWidths(shooting: 62, review: 82)

    private func modeSwitch(labelWidths: ModeLabelWidths = mockLabelWidths) -> ModeSwitchLayout {
        ModeSwitchLayout(frame: layout.modeSwitch, labelWidths: labelWidths)
    }

    @Test("The bottom bar has the cross at 58, 816, the capsule at 91, 792 and the check mark at 344, 816")
    func bottomBar() {
        expectClose(layout.exit, CGRect(x: 34, y: 792, width: 48, height: 48))
        expectClose(layout.modeSwitch, CGRect(x: 91, y: 792, width: 220, height: 48))
        expectClose(layout.accept, CGRect(x: 320, y: 792, width: 48, height: 48))
    }

    @Test("The library button stands left of the shutter at 58, 720")
    func library() {
        expectClose(layout.library, CGRect(x: 34, y: 696, width: 48, height: 48))
        #expect(layout.library.midY == layout.shutter.midY)
        #expect(layout.library.midY == layout.more.midY)
    }

    @Test("The camera flip stands in the top trailing corner at 364, 88 with a radius of 22")
    func flip() {
        expectClose(layout.flip, CGRect(x: 342, y: 66, width: 44, height: 44))
        #expect(layout.flip.midY == layout.topBarButton(at: 0, of: 1).midY)
    }

    @Test("The pills of the two modes are 96 and 116 pt wide for the labels of the mock-up")
    func modeSegments() {
        let modeSwitch = modeSwitch()
        expectClose(modeSwitch.segment(.shooting), CGRect(x: 95, y: 796, width: 96, height: 40))
        expectClose(modeSwitch.segment(.review), CGRect(x: 191, y: 796, width: 116, height: 40))
    }

    @Test(
        "The pills fill the capsule side by side and give both labels the same margins",
        arguments: [
            ModeLabelWidths(shooting: 62, review: 82),
            ModeLabelWidths(shooting: 66.5, review: 61),
            ModeLabelWidths(shooting: 100, review: 100),
            ModeLabelWidths(shooting: 30, review: 150)
        ]
    )
    func modeSegmentMargins(labelWidths: ModeLabelWidths) {
        let modeSwitch = modeSwitch(labelWidths: labelWidths)
        let shooting = modeSwitch.segment(.shooting)
        let review = modeSwitch.segment(.review)
        #expect(shooting.minX == 95)
        #expect(shooting.maxX == review.minX)
        #expect(review.maxX == 307)
        let shootingMargin = Double(shooting.width - labelWidths.shooting)
        let reviewMargin = Double(review.width - labelWidths.review)
        expectClose(shootingMargin, reviewMargin, tolerance: 0.001)
    }

    @Test("A label wider than the capsule leaves the other pill no width instead of a negative one")
    func oversizedLabel() {
        let modeSwitch = modeSwitch(labelWidths: ModeLabelWidths(shooting: 400, review: 40))
        #expect(modeSwitch.segment(.shooting).width == 212)
        #expect(modeSwitch.segment(.review).width == 0)
    }

    @Test("The badge is a circle of radius 10 at 301, 798, over the top trailing corner of the capsule")
    func badge() {
        expectClose(modeSwitch().badge, CGRect(x: 291, y: 788, width: 20, height: 20))
    }

    @Test("A fresh photo's copy takes off from the middle of the viewfinder", arguments: CameraFlowAspectRatio.allCases)
    func captureFlightStart(aspectRatio: CameraFlowAspectRatio) {
        let layout = LayoutWindow.referencePhone.layout(aspectRatio: aspectRatio, panelTileCount: 5)
        let start = layout.captureFlightStart
        #expect(start.midX == layout.viewfinder.midX)
        #expect(start.midY == layout.viewfinder.midY)
        #expect(layout.viewfinder.contains(start))
    }
}
