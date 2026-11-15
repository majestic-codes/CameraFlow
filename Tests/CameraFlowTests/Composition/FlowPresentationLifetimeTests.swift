//
//  FlowPresentationLifetimeTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("The flow of a presenting controller", .temporaryDirectory, .timeLimit(.minutes(1)))
struct FlowPresentationLifetimeTests {
    let harness = FlowHarness()
    let lifetime = FlowPresentationLifetime<FakeMarkupCanvas>()
    let script = CameraFixtureScript(initialState: CameraFlowInitialState())

    /// The flows the presentation made, in their order.
    @MainActor
    private final class MadeFlows {
        var flows: [TestFlowModel] = []
    }

    /// Runs the flow of the presentation as the task of its view does, until the returned task is cancelled.
    private func appear(making madeFlows: MadeFlows) -> Task<Void, Never> {
        Task {
            await lifetime.run(script: script) {
                let flow = harness.makeFlow()
                madeFlows.flows.append(flow)
                return flow
            }
        }
    }

    /// Cancels the task of the view, as a screen presented over it or its dismissal does, and waits for its end.
    private func disappear(_ view: Task<Void, Never>) async {
        view.cancel()
        await view.value
    }

    private var startCount: Int {
        harness.service.calls.filter { call in
            if case .start = call {
                return true
            }
            return false
        }
        .count
    }

    @Test("A screen presented over the flow stops the camera and keeps the set, and the camera comes back after it")
    func coveredFlowKeepsItsSet() async throws {
        let madeFlows = MadeFlows()
        let firstView = appear(making: madeFlows)
        await settle { lifetime.screen?.flow.camera.session.capabilities != nil }
        let flow = try #require(lifetime.screen?.flow)
        await flow.camera.capture()
        let photos = flow.photoSet.photos

        await disappear(firstView)
        #expect(harness.service.calls.last == .stop)
        #expect(flow.photoSet.photos.map(\.id) == photos.map(\.id))
        #expect(photos.flatMap(\.fileURLs).allSatisfy(FlowTestSupport.fileExists))

        let secondView = appear(making: madeFlows)
        await settle { startCount == 2 }
        #expect(madeFlows.flows.count == 1)
        #expect(lifetime.screen?.flow === flow)
        #expect(flow.photoSet.photos.map(\.id) == photos.map(\.id))
        await disappear(secondView)
        lifetime.end()
    }

    @Test("A camera whose first start failed starts again when its view comes back")
    func failedCameraStartsAgain() async throws {
        let madeFlows = MadeFlows()
        harness.service.startError = .cannotUseCamera("Busy")
        let firstView = appear(making: madeFlows)
        await settle { lifetime.screen?.flow.camera.session.failure != nil }
        let flow = try #require(lifetime.screen?.flow)
        await disappear(firstView)

        harness.service.startError = nil
        let secondView = appear(making: madeFlows)
        await settle { flow.camera.session.capabilities != nil }
        #expect(startCount == 2)
        #expect(flow.camera.session.failure == nil)
        #expect(flow.canShoot)
        await disappear(secondView)
        lifetime.end()
    }

    @Test("A camera that fails again when its view comes back starts from the retry")
    func failedCameraRetriedAfterTheCover() async throws {
        let madeFlows = MadeFlows()
        harness.service.startError = .cannotUseCamera("Busy")
        let firstView = appear(making: madeFlows)
        await settle { lifetime.screen?.flow.camera.session.failure != nil }
        let flow = try #require(lifetime.screen?.flow)
        await disappear(firstView)

        let secondView = appear(making: madeFlows)
        await settle { startCount == 2 && !flow.camera.changes.isChanging }
        harness.service.startError = nil
        await flow.camera.retry()
        #expect(flow.camera.session.capabilities != nil)
        #expect(flow.camera.session.failure == nil)
        await disappear(secondView)
        lifetime.end()
    }

    @Test("A camera granted while a screen covered its view starts when the view comes back, and reports to the flow")
    func grantedUnderTheCoverStarts() async throws {
        let madeFlows = MadeFlows()
        harness.service.holdsAuthorization = true
        let firstView = appear(making: madeFlows)
        await settle { harness.service.heldCallCount == 1 }
        let flow = try #require(lifetime.screen?.flow)
        firstView.cancel()
        harness.service.holdsAuthorization = false
        harness.service.releaseHeldCalls()
        await firstView.value
        #expect(startCount == 0)

        let secondView = appear(making: madeFlows)
        await settle { flow.camera.session.capabilities != nil }
        #expect(flow.canShoot)
        await harness.service.simulate(.interrupted(.cameraInUseByAnotherClient))
        #expect(flow.camera.session.interruption == .cameraInUseByAnotherClient)
        await disappear(secondView)
        lifetime.end()
    }

    @Test("The end of the presentation closes the camera, deletes the set nobody accepted and tells the app nothing")
    func endDeletesTheSet() async throws {
        let madeFlows = MadeFlows()
        let view = appear(making: madeFlows)
        await settle { lifetime.screen?.flow.camera.session.capabilities != nil }
        let flow = try #require(lifetime.screen?.flow)
        await flow.camera.capture()
        let photos = flow.photoSet.photos

        lifetime.end()
        await disappear(view)
        #expect(lifetime.screen == nil)
        #expect(flow.camera.delivery.isClosed)
        #expect(flow.photoSet.hasEnded)
        expectDeleted(photos)
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(harness.outcome.exitCount == 0)
    }

    @Test("Every presentation runs a new flow with an empty set")
    func newFlowForEveryPresentation() async throws {
        let madeFlows = MadeFlows()
        let firstView = appear(making: madeFlows)
        await settle { lifetime.screen?.flow.camera.session.capabilities != nil }
        let first = try #require(lifetime.screen?.flow)
        await first.camera.capture()
        lifetime.end()
        await disappear(firstView)

        let secondView = appear(making: madeFlows)
        await settle { lifetime.screen?.flow.camera.session.capabilities != nil }
        let second = try #require(lifetime.screen?.flow)
        #expect(madeFlows.flows.count == 2)
        #expect(second !== first)
        #expect(second.photoSet.isEmpty)
        await disappear(secondView)
        lifetime.end()
    }

    @Test("A flow in the review keeps its camera stopped when its view comes back")
    func reviewStaysStopped() async throws {
        let madeFlows = MadeFlows()
        let firstView = appear(making: madeFlows)
        await settle { lifetime.screen?.flow.camera.session.capabilities != nil }
        let flow = try #require(lifetime.screen?.flow)
        await flow.camera.capture()
        flow.showReview()
        await disappear(firstView)

        let secondView = appear(making: madeFlows)
        await settleQueuedWork()
        #expect(startCount == 1)
        #expect(flow.mode == .review)
        await disappear(secondView)
        lifetime.end()
    }

    @Test("A flow whose set was handed over stays closed when its view comes back, and its controller may go")
    func handedOverStaysClosed() async throws {
        let madeFlows = MadeFlows()
        let firstView = appear(making: madeFlows)
        await settle { lifetime.screen?.flow.camera.session.capabilities != nil }
        let flow = try #require(lifetime.screen?.flow)
        await flow.camera.capture()
        #expect(lifetime.hasFlowEnded == false)
        await flow.accept()
        #expect(lifetime.hasFlowEnded)
        await disappear(firstView)

        let secondView = appear(making: madeFlows)
        await settleQueuedWork()
        #expect(startCount == 1)
        #expect(madeFlows.flows.count == 1)
        await disappear(secondView)
        lifetime.end()
        try #require(harness.outcome.handedOver.count == 1)
        try FlowTestSupport.discardFiles(of: harness.outcome.handedOver[0])
    }

    @Test("Every flow of a presentation tells the presentation's observer of its hand-overs")
    func observedHandOvers() async throws {
        let observer = RecordingHandOverObserver()
        let observedLifetime = FlowPresentationLifetime<FakeMarkupCanvas>(handOverObserver: observer)
        let firstView = Task {
            await observedLifetime.run(script: script) { harness.makeFlow() }
        }
        await settle { observedLifetime.screen?.flow.camera.session.capabilities != nil }
        let first = try #require(observedLifetime.screen?.flow)
        #expect(first.photoSet.handOverObserver === observer)
        observedLifetime.end()
        await disappear(firstView)

        let secondView = Task {
            await observedLifetime.run(script: script) { harness.makeFlow() }
        }
        await settle { observedLifetime.screen?.flow.camera.session.capabilities != nil }
        let second = try #require(observedLifetime.screen?.flow)
        #expect(second !== first)
        #expect(second.photoSet.handOverObserver === observer)
        await second.camera.capture()
        await second.accept()
        #expect(observer.events == [.began, .asked, .ended])
        await disappear(secondView)
        observedLifetime.end()
        try #require(harness.outcome.handedOver.count == 1)
        try FlowTestSupport.discardFiles(of: harness.outcome.handedOver[0])
    }

    @Test("A set accepted before the presentation ended is handed over all the same, and the next flow starts anew")
    func handOverOutlivesThePresentation() async throws {
        let gate = CallGate()
        let gatedHarness = FlowHarness(renderer: RecordingMarkupRenderer(gate: gate))
        let gatedLifetime = FlowPresentationLifetime<FakeMarkupCanvas>()
        let view = Task {
            await gatedLifetime.run(script: script) { gatedHarness.makeFlow() }
        }
        await settle { gatedLifetime.screen?.flow.camera.session.capabilities != nil }
        let flow = try #require(gatedLifetime.screen?.flow)
        await flow.camera.capture()
        let photo = try #require(flow.photoSet.photos.first)
        let drawing = try FlowTestSupport.makeDrawing()
        flow.photoSet.setDrawing(drawing, ofPhoto: photo.id)
        let handingOver = Task { await flow.accept() }
        await gate.arrival()

        gatedLifetime.end()
        await disappear(view)
        #expect(gatedLifetime.hasFlowEnded == false)
        #expect(gatedHarness.outcome.handedOver.isEmpty)
        await gate.open()
        await handingOver.value
        try #require(gatedHarness.outcome.handedOver.count == 1)
        let handedOver = gatedHarness.outcome.handedOver[0]
        #expect(handedOver.flatMap(\.fileURLs).allSatisfy(FlowTestSupport.fileExists))
        try FlowTestSupport.discardFiles(of: handedOver)
    }
}
