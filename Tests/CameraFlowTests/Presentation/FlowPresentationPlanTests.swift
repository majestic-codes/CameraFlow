//
//  FlowPresentationPlanTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@Suite("The rule the public screens present and dismiss the flow by")
struct FlowPresentationPlanTests {

    private func plan(
        isRequested: Bool,
        canPresent: Bool = true,
        phase: FlowPresentationPhase,
        covering: CoveringControllers = .clear,
        hasWaitedNextTurn: Bool = false
    ) -> FlowPresentationPlan {
        FlowPresentationPlan(
            isRequested: isRequested,
            canPresent: canPresent,
            phase: phase,
            covering: covering,
            hasWaitedNextTurn: hasWaitedNextTurn
        )
    }

    // MARK: - Presenting

    @Test("A request with nothing in the way presents the flow from the presenter")
    func presentsWhenClear() {
        #expect(plan(isRequested: true, phase: .absent).step == .present(overPresentedController: false))
    }

    @Test("Nothing is presented without a request, or before the presenter is in a window with its content")
    func presentsOnlyWhenAskedAndAble() {
        #expect(plan(isRequested: false, phase: .absent).step == .stay)
        #expect(plan(isRequested: true, canPresent: false, phase: .absent).step == .stay)
        #expect(plan(isRequested: true, canPresent: false, phase: .absent, covering: .moving).step == .stay)
    }

    @Test("A sheet that is leaving, as one closed in the same action, is waited for before the flow comes")
    func waitsForALeavingSheet() {
        #expect(plan(isRequested: true, phase: .absent, covering: .moving).step == .retryAfterTransition)
        let waited = plan(isRequested: true, phase: .absent, covering: .moving, hasWaitedNextTurn: true)
        #expect(waited.step == .retryAfterTransition)
    }

    @Test("A sheet that stays gets a turn to start leaving, and then the flow over it")
    func presentsOverASheetThatStays() {
        #expect(plan(isRequested: true, phase: .absent, covering: .settled).step == .retryNextTurn)
        let waited = plan(isRequested: true, phase: .absent, covering: .settled, hasWaitedNextTurn: true)
        #expect(waited.step == .present(overPresentedController: true))
    }

    // MARK: - On screen

    @Test("A flow that is on screen, or on its way, takes new content while it is asked for")
    func updatesContent() {
        #expect(plan(isRequested: true, phase: .shown).step == .updateContent)
        #expect(plan(isRequested: true, phase: .shown, covering: .settled).step == .updateContent)
        #expect(plan(isRequested: true, phase: .appearing).step == .updateContent)
    }

    // MARK: - Dismissing

    @Test("A flow no longer asked for is dismissed, with the sheet or the alert it shows")
    func dismisses() {
        #expect(plan(isRequested: false, phase: .shown).step == .dismiss)
        #expect(plan(isRequested: false, phase: .shown, covering: .settled).step == .dismiss)
    }

    @Test("A dismissal waits while a sheet of the flow is still sliding away")
    func dismissalWaitsForATransition() {
        #expect(plan(isRequested: false, phase: .shown, covering: .moving).step == .retryAfterTransition)
    }

    @Test("A flow on its way onto the screen is dismissed once it is there, and one that is leaving is left to go")
    func dismissalAfterThePresentation() {
        #expect(plan(isRequested: false, phase: .appearing).step == .stay)
        #expect(plan(isRequested: false, phase: .leaving).step == .stay)
        #expect(plan(isRequested: true, phase: .leaving).step == .stay)
    }

    @Test("A controller that dismisses itself does so whatever its content, as the plan of a shown flow says")
    func controllerDismissal() {
        #expect(plan(isRequested: false, canPresent: false, phase: .shown).step == .dismiss)
        #expect(plan(isRequested: false, canPresent: false, phase: .absent).step == .stay)
    }
}
