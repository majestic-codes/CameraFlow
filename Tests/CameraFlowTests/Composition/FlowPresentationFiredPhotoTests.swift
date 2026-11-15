//
//  FlowPresentationFiredPhotoTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 15.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// A screen presented over the flow while a photo is on its way: the camera stops once the photo is delivered.
@MainActor
@Suite("The flow of a presenting controller: a photo on its way", .temporaryDirectory, .timeLimit(.minutes(1)))
struct FlowPresentationFiredPhotoTests {
    let harness = FlowHarness()
    let lifetime = FlowPresentationLifetime<FakeMarkupCanvas>()
    let script = CameraFixtureScript(initialState: CameraFlowInitialState())

    /// Runs the flow of the presentation as the task of its view does, until the returned task is cancelled.
    private func appear() -> Task<Void, Never> {
        Task {
            await lifetime.run(script: script) {
                harness.makeFlow()
            }
        }
    }

    /// Cancels the task of the view, as a screen presented over it does, and waits for its end.
    private func disappear(_ view: Task<Void, Never>) async {
        view.cancel()
        await view.value
    }

    private var stopCount: Int {
        harness.service.calls.filter { $0 == .stop }.count
    }

    /// Lets the tasks that wait on the main actor run for a while.
    private func yieldForAWhile() async {
        for _ in 0..<50 {
            await Task.yield()
        }
    }

    @Test("A screen presented over a photo on its way stops the camera once the photo is delivered, into the set")
    func coverWaitsForTheFiredPhoto() async throws {
        let view = appear()
        await settle { lifetime.screen?.flow.camera.session.capabilities != nil }
        let flow = try #require(lifetime.screen?.flow)
        harness.service.holdsCalls = true
        let shot = Task { await flow.camera.capture() }
        await settle { harness.service.heldCallCount == 1 }

        view.cancel()
        await yieldForAWhile()
        #expect(stopCount == 0)
        harness.service.holdsCalls = false
        harness.service.releaseHeldCalls()
        await shot.value
        await view.value
        #expect(flow.photoSet.photos.count == 1)
        #expect(flow.camera.notices.captureError == nil)
        #expect(harness.service.calls.last == .stop)
        lifetime.end()
    }

    @Test("A view that comes back while a fired photo is on its way keeps the camera running")
    func viewBackDuringTheWait() async throws {
        let firstView = appear()
        await settle { lifetime.screen?.flow.camera.session.capabilities != nil }
        let flow = try #require(lifetime.screen?.flow)
        harness.service.holdsCalls = true
        let shot = Task { await flow.camera.capture() }
        await settle { harness.service.heldCallCount == 1 }

        firstView.cancel()
        await yieldForAWhile()
        let secondView = appear()
        await yieldForAWhile()
        harness.service.holdsCalls = false
        harness.service.releaseHeldCalls()
        await shot.value
        await firstView.value
        await settle { !flow.camera.changes.isChanging }
        #expect(stopCount == 0)
        #expect(flow.photoSet.photos.count == 1)
        #expect(flow.canShoot)
        await disappear(secondView)
        #expect(stopCount == 1)
        lifetime.end()
    }
}
