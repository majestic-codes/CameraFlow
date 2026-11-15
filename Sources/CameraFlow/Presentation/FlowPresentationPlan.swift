//
//  FlowPresentationPlan.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// Where the controller of the flow stands in its presentation.
enum FlowPresentationPhase: Equatable, Sendable {
    /// Not presented: never yet, or dismissed.
    case absent
    /// On its way onto the screen.
    case appearing
    case shown
    /// Asked to leave, and not gone yet.
    case leaving
}

/// What stands over the place the flow is presented from, or over the flow once it is there.
enum CoveringControllers: Equatable, Sendable {
    /// Nothing is presented there.
    case clear
    /// A presentation or a dismissal runs, and the system takes no other one until it ends.
    case moving
    /// A controller is presented and stays.
    case settled
}

/// What the presenter of the flow does next.
enum FlowPresentationStep: Equatable, Sendable {
    /// Leaves everything as it is.
    case stay
    /// Presents the flow, from the controller presented on top when `overPresentedController` is true.
    case present(overPresentedController: Bool)
    /// Hands the flow on screen its content again.
    case updateContent
    /// Dismisses the flow through the controller that presented it, which takes down what the flow presents too.
    case dismiss
    /// Tries again once the running presentation or dismissal has ended.
    case retryAfterTransition
    /// Tries again on the next turn of the main queue: a presentation in the way may start leaving in this one.
    case retryNextTurn
}

/// The rule `cameraFlowCover` and `CameraFlowViewController` follow to put the flow on screen and take it away
/// without the system refusing it: nothing moves while a presentation or a dismissal runs, the flow goes through
/// the controller that presented it with all it presents itself, and a controller that stays presented gets the flow
/// over it after one turn, in which it may start to leave.
struct FlowPresentationPlan: Equatable, Sendable {
    /// Whether the flow is asked for: the binding of the cover. A controller that dismisses itself asks for none.
    let isRequested: Bool
    /// Whether the flow can be presented now: the presenter is in a window and has the content.
    let canPresent: Bool
    let phase: FlowPresentationPhase
    /// What stands over the presenter while the flow is absent, or over the flow while it is there.
    let covering: CoveringControllers
    /// Whether this request has already waited a turn for a controller that stays presented.
    let hasWaitedNextTurn: Bool

    var step: FlowPresentationStep {
        switch phase {
        case .absent: presentationStep
        case .appearing: isRequested ? .updateContent : .stay
        case .shown: shownStep
        case .leaving: .stay
        }
    }

    private var presentationStep: FlowPresentationStep {
        guard isRequested, canPresent else { return .stay }
        return switch covering {
        case .clear: .present(overPresentedController: false)
        case .moving: .retryAfterTransition
        case .settled: hasWaitedNextTurn ? .present(overPresentedController: true) : .retryNextTurn
        }
    }

    private var shownStep: FlowPresentationStep {
        guard !isRequested else { return .updateContent }
        return covering == .moving ? .retryAfterTransition : .dismiss
    }
}
