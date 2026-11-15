//
//  ModeSwitchTrackingTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

@Suite("Mode switch tracking")
struct ModeSwitchTrackingTests {
    static let labelWidths = ModeLabelWidths(shooting: 62, review: 82)
    static let layout = ModeSwitchLayout(frame: CGRect(x: 91, y: 792, width: 220, height: 48), labelWidths: labelWidths)
    let open = ModeSwitchTracking(travel: 96, canReachReview: true)
    let closed = ModeSwitchTracking(travel: 96, canReachReview: false)
    let limit = FlowMetrics.ModeSwitch.rubberBandLimit

    // MARK: - Under the finger

    @Test(
        "Between the ends the thumb follows the finger one to one",
        arguments: [
            (CameraFlowMode.shooting, 0.0, 0.0),
            (.shooting, 24, 0.25),
            (.shooting, 96, 1),
            (.review, -48, 0.5),
            (.review, 0, 1)
        ]
    )
    func followsFinger(start: CameraFlowMode, translation: Double, expected: Double) {
        let progress = open.progress(from: start, translation: CGFloat(translation))
        expectClose(progress, expected, tolerance: 0.0001)
    }

    @Test("Past an end the thumb gives way, always further, never beyond the limit")
    func rubberBand() {
        var previous: CGFloat = 0
        for overshoot in stride(from: 1.0, through: 2000.0, by: 7.0) {
            let band = ModeSwitchTracking.band(CGFloat(overshoot))
            #expect(band > previous)
            #expect(band < limit)
            previous = band
        }
        #expect(ModeSwitchTracking.band(0) == 0)
    }

    @Test("The band is mild: a short pull moves the thumb by less than the pull")
    func bandIsMild() {
        let band = ModeSwitchTracking.band(10)
        #expect(band > 0 && band < 10)
    }

    @Test("Pulled beyond either end, the thumb stays within the limit of it")
    func pulledBeyondEnds() {
        let beyondReview = open.progress(from: .review, translation: 500)
        let beforeShooting = open.progress(from: .shooting, translation: -500)
        #expect(beyondReview > 1 && beyondReview * 96 < 96 + limit)
        #expect(beforeShooting < 0 && beforeShooting * 96 > -limit)
    }

    @Test("While the review is out of reach, the thumb pulled towards it gives way at the shooting")
    func refusedPull() {
        let progress = closed.progress(from: .shooting, translation: 96)
        #expect(progress > 0)
        #expect(progress * 96 < limit)
        #expect(closed.progress(from: .shooting, translation: -96) < 0)
    }

    @Test("Stretch grows with the speed, either way, and never passes its limit")
    func stretch() {
        #expect(ModeSwitchTracking.stretch(velocity: 0) == 0)
        #expect(ModeSwitchTracking.stretch(velocity: 600) == ModeSwitchTracking.stretch(velocity: -600))
        #expect(ModeSwitchTracking.stretch(velocity: 600) < ModeSwitchTracking.stretch(velocity: 900))
        #expect(ModeSwitchTracking.stretch(velocity: 100_000) == FlowMetrics.ModeSwitch.stretchLimit)
    }

    // MARK: - At the release

    @Test(
        "The thumb settles on the nearer mode",
        arguments: [
            (CameraFlowMode.shooting, 10.0, CameraFlowMode.shooting),
            (.shooting, 47, .shooting),
            (.shooting, 60, .review),
            (.shooting, 96, .review),
            (.review, -10, .review),
            (.review, -60, .shooting)
        ]
    )
    func nearerMode(start: CameraFlowMode, translation: Double, expected: CameraFlowMode) {
        let mode = open.proposedMode(from: start, translation: CGFloat(translation), velocity: 0)
        #expect(mode == expected)
    }

    @Test("A short quick flick towards the other mode switches it, a slow one does not")
    func flick() {
        #expect(open.proposedMode(from: .shooting, translation: 20, velocity: 600) == .review)
        #expect(open.proposedMode(from: .shooting, translation: 20, velocity: 50) == .shooting)
        #expect(open.proposedMode(from: .review, translation: -20, velocity: -600) == .shooting)
        #expect(open.proposedMode(from: .review, translation: -20, velocity: 600) == .review)
    }

    @Test("A drag past the midpoint that is flicked back returns to where it began")
    func flickedBack() {
        #expect(open.proposedMode(from: .shooting, translation: 60, velocity: -800) == .shooting)
    }

    @Test("The review is asked for but not reached while the set is empty")
    func closedReview() {
        #expect(closed.proposedMode(from: .shooting, translation: 90, velocity: 0) == .review)
        #expect(closed.reachable(.review) == .shooting)
        #expect(open.reachable(.review) == .review)
        #expect(closed.reachable(.shooting) == .shooting)
    }

    @Test("A touch that moves less than the slop is a tap")
    func tap() {
        #expect(open.isTap(translation: CGSize(width: 3, height: 0)))
        #expect(open.isTap(translation: CGSize(width: -3, height: 2)))
        #expect(open.isTap(translation: CGSize(width: 12, height: 0)) == false)
    }

    @Test("A finger that slides away up or down is no tap, however little it moves sideways")
    func verticalDragIsNoTap() {
        #expect(open.isTap(translation: CGSize(width: 2, height: 40)) == false)
        #expect(open.isTap(translation: CGSize(width: 0, height: -200)) == false)
        #expect(open.isTap(translation: CGSize(width: 4, height: 5)) == false)
    }

    @Test("The settling starts at the speed of the finger in distances to the target per second")
    func settleVelocity() {
        #expect(open.settleVelocity(from: 0.5, to: .review, fingerVelocity: 48) == 1)
        #expect(open.settleVelocity(from: 0.5, to: .shooting, fingerVelocity: 48) == -1)
        #expect(open.settleVelocity(from: 1, to: .review, fingerVelocity: 500) == 0)
        let fast = open.settleVelocity(from: 0.1, to: .review, fingerVelocity: 1_000_000)
        #expect(fast == FlowMetrics.ModeSwitch.settleVelocityLimit)
    }

    // MARK: - The thumb in the capsule

    @Test("The thumb is the pill of each mode at its end and between them in the middle")
    func thumbFrames() {
        let layout = Self.layout
        #expect(layout.thumb(at: 0) == layout.segment(.shooting))
        #expect(layout.thumb(at: 1) == layout.segment(.review))
        let middle = layout.thumb(at: 0.5)
        expectClose(middle.minX, layout.segment(.shooting).minX + layout.travel / 2, tolerance: 0.001)
        #expect(middle.height == layout.segment(.shooting).height)
    }

    @Test("The travel is the width of the first pill")
    func travel() {
        #expect(Self.layout.travel == Self.layout.segment(.shooting).width)
        #expect(Self.layout.insideCapsule.frame.origin == .zero)
    }

    @Test("A place across the capsule belongs to the pill under it")
    func modeAtPoint() {
        let local = Self.layout.insideCapsule
        #expect(local.mode(atOffset: 10) == .shooting)
        #expect(local.mode(atOffset: local.segment(.review).minX - 1) == .shooting)
        #expect(local.mode(atOffset: local.segment(.review).minX + 1) == .review)
        #expect(local.mode(atOffset: 210) == .review)
    }

    @Test(
        "How much of a label the thumb covers goes from 0 to 1 and back as the thumb passes",
        arguments: [0.0, 0.25, 0.5, 0.75, 1.0]
    )
    func coverage(progress: Double) {
        let layout = Self.layout
        let thumb = layout.thumb(at: CGFloat(progress))
        let shooting = Self.coverage(of: .shooting, by: thumb, in: layout)
        let review = Self.coverage(of: .review, by: thumb, in: layout)
        #expect((0...1).contains(shooting) && (0...1).contains(review))
        if progress == 0 {
            #expect(shooting == 1 && review == 0)
        } else if progress == 1 {
            #expect(shooting == 0 && review == 1)
        } else {
            #expect(shooting > 0 && shooting < 1)
            #expect(review > 0)
        }
    }

    @Test("The covered share of one label only falls and of the other only rises")
    func coverageMonotonic() {
        let layout = Self.layout
        let steps = (0...20).map { CGFloat($0) / 20 }
        let shooting = steps.map { Self.coverage(of: .shooting, by: layout.thumb(at: $0), in: layout) }
        let review = steps.map { Self.coverage(of: .review, by: layout.thumb(at: $0), in: layout) }
        #expect(zip(shooting, shooting.dropFirst()).allSatisfy { $0 >= $1 })
        #expect(zip(review, review.dropFirst()).allSatisfy { $0 <= $1 })
    }

    /// The share of the width of a label, centred in its pill, that the thumb covers.
    private static func coverage(of mode: CameraFlowMode, by thumb: CGRect, in layout: ModeSwitchLayout) -> CGFloat {
        let pill = layout.segment(mode)
        let width = mode == .shooting ? layout.labelWidths.shooting : layout.labelWidths.review
        let label = CGRect(x: pill.midX - width / 2, y: pill.minY, width: width, height: pill.height)
        return max(0, min(label.maxX, thumb.maxX) - max(label.minX, thumb.minX)) / width
    }
}
