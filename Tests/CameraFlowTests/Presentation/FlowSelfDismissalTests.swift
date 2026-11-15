//
//  FlowSelfDismissalTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

/// The dismissal the controller of the flow asks of itself once its flow has ended, and what a controller presented
/// again keeps of it.
@Suite("The dismissal the controller asks of itself")
struct FlowSelfDismissalTests {

    @Test("A shown controller goes at once, and asks nothing more of a later appearance")
    func shown() {
        var dismissal = FlowSelfDismissal()
        #expect(dismissal.request(phase: .shown, covering: .clear) == .dismiss)
        #expect(dismissal.isPending == false)
        #expect(dismissal.proceed(phase: .shown, covering: .clear) == .stay)
    }

    @Test("A controller on its way onto the screen goes once it is there, and once only")
    func appearing() {
        var dismissal = FlowSelfDismissal()
        #expect(dismissal.request(phase: .appearing, covering: .moving) == .stay)
        #expect(dismissal.isPending)
        #expect(dismissal.proceed(phase: .shown, covering: .clear) == .dismiss)
        #expect(dismissal.isPending == false)
        #expect(dismissal.proceed(phase: .shown, covering: .clear) == .stay)
    }

    @Test("A sheet of the flow that slides away is waited for, then the controller goes")
    func transition() {
        var dismissal = FlowSelfDismissal()
        #expect(dismissal.request(phase: .shown, covering: .moving) == .retryAfterTransition)
        #expect(dismissal.isPending)
        #expect(dismissal.proceed(phase: .shown, covering: .clear) == .dismiss)
        #expect(dismissal.isPending == false)
    }

    @Test(
        "A dismissal asked for while the controller leaves or once it is gone ends there: presented again, it stays",
        arguments: [FlowPresentationPhase.leaving, .absent]
    )
    func presentedAgain(phase: FlowPresentationPhase) {
        var dismissal = FlowSelfDismissal()
        #expect(dismissal.request(phase: phase, covering: .moving) == .stay)
        #expect(dismissal.isPending == false)
        #expect(dismissal.proceed(phase: .appearing, covering: .moving) == .stay)
        #expect(dismissal.proceed(phase: .shown, covering: .clear) == .stay)
        #expect(dismissal.isPending == false)
    }

    @Test("Without a request nothing is dismissed, whatever the controller does")
    func withoutRequest() {
        var dismissal = FlowSelfDismissal()
        #expect(dismissal.proceed(phase: .shown, covering: .clear) == .stay)
        #expect(dismissal.proceed(phase: .shown, covering: .moving) == .stay)
        #expect(dismissal.isPending == false)
    }
}
