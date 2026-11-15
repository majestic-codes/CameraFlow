//
//  ExitWithPhotosInFlightTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// The ways out while photos the camera took are on their way into the set: leaving would delete them, so the cross
/// asks first as it does for a set with photos, and the alert follows the photos as they land or fail.
@MainActor
@Suite("Leaving with photos on their way", .temporaryDirectory, .timeLimit(.minutes(1)))
struct ExitWithPhotosInFlightTests {
    let harness = FlowHarness()

    /// A flow whose camera runs and holds every shot until the test lets it go.
    private func makeHoldingFlow(
        limit: CameraFlowPhotoLimit = .unlimited,
        completion: CameraFlowCompletion = .userConfirms
    ) async -> TestFlowModel {
        let flow = harness.makeFlow(limit: limit, completion: completion)
        await flow.camera.start()
        harness.service.holdsCalls = true
        return flow
    }

    /// Taps the shutter `count` times and returns once the camera holds every shot.
    private func tap(_ flow: TestFlowModel, times count: Int) async -> [Task<Void, Never>] {
        var taps: [Task<Void, Never>] = []
        for _ in 0..<count {
            taps.append(Task { await flow.camera.capture() })
            let tapCount = taps.count
            await settle { harness.service.heldCallCount == tapCount }
        }
        return taps
    }

    private func finish(_ taps: [Task<Void, Never>]) async {
        for tap in taps {
            await tap.value
        }
    }

    @Test("The cross during a burst on an empty set asks first, every photo on its way counted")
    func burstOnEmptySet() async throws {
        let flow = await makeHoldingFlow()
        let taps = await tap(flow, times: 3)
        #expect(flow.photoSet.isEmpty)
        #expect(flow.camera.firedPhotosInFlight == 3)
        flow.requestExit()
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 3, hasCameraPhotos: true))
        #expect(harness.outcome.exitCount == 0)
        #expect(flow.photoSet.hasEnded == false)
        #expect(flow.acceptsCaptureButtons == false)
        let message = "The set has 3 photos. The ones taken with the camera will be gone for good."
        #expect(try FlowText(.system).exitMessage(for: #require(flow.exitConfirmation)) == message)
        await harness.service.releaseHeldCaptures(inTurn: 1)
        await taps[0].value
        #expect(flow.photoSet.count == 1)
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 3, hasCameraPhotos: true))
        await harness.service.releaseHeldCaptures(inTurn: 2)
        await finish(taps)
        #expect(flow.photoSet.count == 3)
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 3, hasCameraPhotos: true))
        let photos = flow.photoSet.photos
        flow.confirmExit()
        #expect(harness.outcome.exitCount == 1)
        expectDeleted(photos)
        #expect(FlowTestSupport.fileExists(harness.files.directory) == false)
    }

    @Test("A press of the shutter on a set with photos counts its photo beside them while the alert is up")
    func burstBesideSetPhotos() async throws {
        let flow = harness.makeFlow()
        await flow.camera.start()
        try await harness.importLibraryPhoto(into: flow)
        harness.service.holdsCalls = true
        let taps = await tap(flow, times: 1)
        flow.requestExit()
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 2, hasCameraPhotos: true))
        flow.cancelExit()
        harness.service.releaseHeldCalls()
        await finish(taps)
        #expect(flow.photoSet.count == 2)
        flow.photoSet.discard()
    }

    /// The second photo is delivered first and waits for the turn of the first, so it is still on its way when the
    /// user leaves, and reaches the delivery once the flow is gone.
    @Test("Leaving while photos are on their way deletes them as their shots end, and the app hears the exit once")
    func leaveWhilePhotosAreOnTheirWay() async {
        let flow = await makeHoldingFlow()
        let taps = await tap(flow, times: 2)
        harness.service.releaseHeldCapture(at: 1)
        await settle { harness.service.endedCaptureCount == 1 }
        #expect(flow.camera.firedPhotosInFlight == 2)
        flow.requestExit()
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 2, hasCameraPhotos: true))
        flow.confirmExit()
        #expect(flow.exitConfirmation == nil)
        await finish(taps)
        #expect(harness.outcome.exitCount == 1)
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(flow.photoSet.isEmpty)
        #expect(flow.camera.photosInFlight == 0)
        #expect(FlowTestSupport.fileExists(harness.files.directory) == false)
    }

    @Test("Staying keeps the photos on their way, which land in the set as they come")
    func stayWhilePhotosAreOnTheirWay() async {
        let flow = await makeHoldingFlow()
        let taps = await tap(flow, times: 2)
        flow.requestExit()
        flow.cancelExit()
        #expect(flow.exitConfirmation == nil)
        #expect(flow.acceptsCaptureButtons)
        await harness.service.releaseHeldCaptures(inTurn: 2)
        await finish(taps)
        #expect(flow.photoSet.count == 2)
        #expect(harness.outcome.exitCount == 0)
        #expect(flow.canAccept)
        flow.photoSet.discard()
    }

    @Test("While the alert is up, a photo that fails is no longer counted, and the rest still are")
    func photoFailsWhileAsking() async throws {
        let flow = await makeHoldingFlow()
        let taps = await tap(flow, times: 2)
        flow.requestExit()
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 2, hasCameraPhotos: true))
        harness.service.captureError = .captureFailed("The sensor gave nothing")
        await harness.service.releaseHeldCaptures(inTurn: 1)
        await taps[0].value
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 1, hasCameraPhotos: true))
        let message = "The set has 1 photo. It was taken with the camera and will be gone for good."
        #expect(try FlowText(.system).exitMessage(for: #require(flow.exitConfirmation)) == message)
        harness.service.captureError = nil
        await harness.service.releaseHeldCaptures(inTurn: 1)
        await taps[1].value
        #expect(flow.photoSet.count == 1)
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 1, hasCameraPhotos: true))
        let photos = flow.photoSet.photos
        flow.confirmExit()
        #expect(harness.outcome.exitCount == 1)
        expectDeleted(photos)
    }

    @Test("When the last photo on its way fails, the alert has nothing left to ask: it closes and the flow stays")
    func lastPhotoFailsWhileAsking() async {
        let flow = await makeHoldingFlow()
        let taps = await tap(flow, times: 1)
        flow.requestExit()
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 1, hasCameraPhotos: true))
        harness.service.captureError = .captureFailed("The sensor gave nothing")
        harness.service.releaseHeldCalls()
        await finish(taps)
        #expect(flow.exitConfirmation == nil)
        #expect(harness.outcome.exitCount == 0)
        #expect(flow.photoSet.hasEnded == false)
        #expect(flow.notice == .camera(.captureFailed(.captureFailed("The sensor gave nothing"))))
        #expect(flow.acceptsCaptureButtons)
        #expect(flow.canShoot)
        flow.requestExit()
        #expect(harness.outcome.exitCount == 1)
    }

    @Test("A running countdown has no photo yet: the cross leaves an empty set at once and stops it")
    func countdownIsNoPhoto() async {
        var state = CameraFlowInitialState()
        state.timer.value = .threeSeconds
        let flow = harness.makeFlow(initialState: state)
        await flow.camera.start()
        let shutter = Task { await flow.camera.capture() }
        await harness.clock.waitForSleepers()
        #expect(flow.camera.photosInFlight == 1)
        #expect(flow.camera.firedPhotosInFlight == 0)
        flow.requestExit()
        #expect(harness.outcome.exitCount == 1)
        #expect(flow.exitConfirmation == nil)
        await shutter.value
        #expect(harness.service.captureRequests.isEmpty)
    }

    @Test("A photo counts as on its way from the moment its countdown fires its shot until it lands")
    func photoOnItsWayAfterCountdown() async {
        var state = CameraFlowInitialState()
        state.timer.value = .threeSeconds
        let flow = harness.makeFlow(initialState: state)
        await flow.camera.start()
        harness.service.holdsCalls = true
        let shutter = Task { await flow.camera.capture() }
        for _ in 0..<3 {
            await harness.clock.waitForSleepers()
            harness.clock.advance(by: .seconds(1))
        }
        await settle { harness.service.heldCallCount == 1 }
        #expect(flow.camera.firedPhotosInFlight == 1)
        flow.requestExit()
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 1, hasCameraPhotos: true))
        flow.cancelExit()
        harness.service.releaseHeldCalls()
        await shutter.value
        #expect(flow.camera.firedPhotosInFlight == 0)
        #expect(flow.photoSet.count == 1)
        flow.photoSet.discard()
    }

    @Test("In a flow that ends after one photo, the photo that lands while the alert asks waits: Stay hands it over")
    func afterOnePhotoStay() async throws {
        let flow = await makeHoldingFlow(limit: .maximum(1), completion: .afterOnePhoto)
        let taps = await tap(flow, times: 1)
        flow.requestExit()
        harness.service.releaseHeldCalls()
        await finish(taps)
        await settleQueuedWork()
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(flow.photoSet.count == 1)
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 1, hasCameraPhotos: true))
        flow.cancelExit()
        await settle { harness.outcome.handedOver.count == 1 }
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.count == 1)
        #expect(flow.photoSet.hasEnded)
        #expect(harness.outcome.exitCount == 0)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("In a flow that ends after one photo, Leave deletes the photo that landed while the alert asked")
    func afterOnePhotoLeave() async {
        let flow = await makeHoldingFlow(limit: .maximum(1), completion: .afterOnePhoto)
        let taps = await tap(flow, times: 1)
        flow.requestExit()
        harness.service.releaseHeldCalls()
        await finish(taps)
        await settleQueuedWork()
        let photos = flow.photoSet.photos
        #expect(photos.count == 1)
        flow.confirmExit()
        // The alert's binding closes it after the answer, which then stays without effect.
        flow.cancelExit()
        await settleQueuedWork()
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(harness.outcome.exitCount == 1)
        expectDeleted(photos)
    }
}
