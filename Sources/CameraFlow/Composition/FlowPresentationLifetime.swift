//
//  FlowPresentationLifetime.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Observation

/// The flow of a controller that presents it, the cover of `cameraFlowCover` or `CameraFlowViewController`: one flow
/// for each presentation, from the first appearance of its view to the dismissal of the controller.
///
/// A screen the app presents full screen over the flow takes the flow's view out of the window and cancels its task.
/// The flow outlives that: its camera stops once the photos already fired are delivered, its set stays, and the
/// camera comes back with the view. The flow ends with its presentation: its camera closes and its set is discarded,
/// unless it was handed over.
@MainActor
@Observable
final class FlowPresentationLifetime<Canvas: MarkupCanvas> {
    /// The flow of the presentation, nil before its view first appears and once the presentation has ended.
    private(set) var screen: FlowScreenModels<Canvas>?
    /// Whether the camera of the flow was started once, so a later run resumes it.
    @ObservationIgnored private var hasStartedCamera = false
    /// How many runs have begun, so that a run that ends after a later one began leaves the camera to it.
    @ObservationIgnored private var runCount = 0
    /// The receivers of the events of the presentation's flows, which the latest view of the flow updates, so a
    /// view created again reaches the flow that runs.
    let receivers = FlowReceivers()
    /// Hears the hand-overs of every flow of the presentation: the relay of the controller that presents them, nil
    /// where the flow's `onFinish` alone receives the set.
    private let handOverObserver: (any PhotoSetHandOverObserver)?

    init(handOverObserver: (any PhotoSetHandOverObserver)? = nil) {
        self.handOverObserver = handOverObserver
    }

    /// Whether the flow of the presentation has ended, handed over or left, so its controller may go.
    var hasFlowEnded: Bool {
        guard let screen else { return false }
        return screen.flow.photoSet.hasEnded
    }

    /// Runs the flow of the presentation for as long as the calling task lives, the task of the flow's view. The
    /// first run of a presentation makes the flow with `makeFlow` and starts its camera, after which the script plays.
    /// A later run brings the camera back as `CameraScreenLifetime.resume(_:)` does. When the task is cancelled the
    /// camera stops once the photos already fired are delivered, and the set stays with them. A later run or the end
    /// of the presentation that comes while those photos are on their way leaves the camera to it.
    func run(script: CameraFixtureScript, makeFlow: () -> CameraFlowModel<Canvas>) async {
        let screen = self.screen ?? begin(makeFlow())
        runCount += 1
        let run = runCount
        if hasStartedCamera {
            await CameraScreenLifetime.resume(screen.flow)
        } else {
            hasStartedCamera = true
            await screen.flow.camera.start()
            await script.play(on: screen.flow.camera)
        }
        await CameraScreenLifetime.waitUntilCancelled()
        guard run == runCount, self.screen?.flow === screen.flow else { return }
        await screen.flow.camera.stopAfterFiredPhotos {
            run == runCount && self.screen?.flow === screen.flow
        }
    }

    /// Ends the flow of the presentation: its camera closes and its set is discarded, unless it was handed over. A set
    /// that is being handed over just then is handed over all the same. The next run makes a new flow.
    func end() {
        guard let screen else { return }
        self.screen = nil
        hasStartedCamera = false
        CameraScreenLifetime.end(screen.flow)
    }

    private func begin(_ flow: CameraFlowModel<Canvas>) -> FlowScreenModels<Canvas> {
        flow.photoSet.handOverObserver = handOverObserver
        let screen = FlowScreenModels(flow: flow)
        self.screen = screen
        return screen
    }
}
