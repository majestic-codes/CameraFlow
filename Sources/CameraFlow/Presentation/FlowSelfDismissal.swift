//
//  FlowSelfDismissal.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The dismissal `CameraFlowViewController` asks of itself once its flow has ended, by the rule of
/// `FlowPresentationPlan`. It waits while the controller is on its way onto the screen or a transition runs. It ends
/// once it runs, and once the controller leaves or is gone, so a controller presented again never inherits it.
struct FlowSelfDismissal: Equatable, Sendable {
    /// Whether the dismissal still waits to run.
    private(set) var isPending = false

    /// The flow of the controller has ended and the controller asks to go: what it does now.
    mutating func request(phase: FlowPresentationPhase, covering: CoveringControllers) -> FlowPresentationStep {
        isPending = true
        return proceed(phase: phase, covering: covering)
    }

    /// What a waiting dismissal does now that the controller has appeared or a transition has ended, `.stay` without
    /// one.
    mutating func proceed(phase: FlowPresentationPhase, covering: CoveringControllers) -> FlowPresentationStep {
        guard isPending else { return .stay }
        let plan = FlowPresentationPlan(
            isRequested: false,
            canPresent: false,
            phase: phase,
            covering: covering,
            hasWaitedNextTurn: false
        )
        let step = plan.step
        isPending = switch step {
        case .retryAfterTransition: true
        case .dismiss: false
        // A controller on its way onto the screen goes once it is there. One that leaves or is gone has nothing left
        // to dismiss.
        case .stay, .present, .updateContent, .retryNextTurn: phase == .appearing
        }
        return step
    }
}
