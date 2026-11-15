//
//  PhotoLimitInFlightTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// The photo limit while photos are on their way from the shutter: they count against it, so a set never gets one
/// photo more than it takes, and the review, the check mark and the library wait for all of them.
@MainActor
@Suite("The photo limit with photos on their way", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoLimitInFlightTests {
    let harness = FlowHarness()

    /// Taps the shutter `count` times and returns once the camera holds every shot.
    private func tap(_ flow: TestFlowModel, times count: Int) async -> [Task<Void, Never>] {
        harness.service.holdsCalls = true
        var taps: [Task<Void, Never>] = []
        for _ in 0..<count {
            taps.append(Task { await flow.camera.capture() })
            let tapCount = taps.count
            await settle { harness.service.heldCallCount == tapCount }
        }
        return taps
    }

    @Test(
        "The room of a set of two counts the photos on their way into it",
        arguments: [(0, 0, true), (0, 1, true), (0, 2, false), (1, 1, false), (2, 0, false)]
    )
    func room(photoCount: Int, photosInFlight: Int, hasRoom: Bool) throws {
        let photoSet = PhotoSetModel(
            limit: .maximum(2),
            fileStore: harness.files,
            renderer: harness.renderer
        ) { _ in
            Issue.record("Nothing is handed over")
        }
        for _ in 0..<photoCount {
            try photoSet.add(FlowTestSupport.makeCapture(in: harness.files))
        }
        #expect(photoSet.hasRoom(besides: photosInFlight) == hasRoom)
        let refusal = photoSet.captureRefusal(photosInFlight: photosInFlight)
        #expect(refusal == (hasRoom ? nil : .captureLimitReached(2)))
        photoSet.discard()
    }

    @Test("A set without a limit has room beside any number of photos on their way")
    func unlimitedRoom() {
        let photoSet = PhotoSetModel(limit: .unlimited, fileStore: harness.files, renderer: harness.renderer) { _ in
            Issue.record("Nothing is handed over")
        }
        #expect(photoSet.hasRoom(besides: 100))
        #expect(photoSet.captureRefusal(photosInFlight: 100) == nil)
    }

    @Test("Photos on their way fill the set: the shutter stops, and a press beyond the limit is refused")
    func photosInFlightFillTheSet() async throws {
        let flow = harness.makeFlow(limit: .maximum(2))
        await flow.camera.start()
        let taps = await tap(flow, times: 2)
        #expect(flow.photoSet.isEmpty)
        #expect(flow.camera.photosInFlight == 2)
        #expect(flow.canShoot == false)
        harness.service.holdsCalls = false
        let refused = Task { await flow.camera.capture() }
        await settleQueuedWork()
        #expect(flow.camera.notices.captureError == .captureLimitReached(2))
        #expect(harness.service.captureRequests.count == 2)
        await harness.service.releaseHeldCaptures(inTurn: 2)
        for tap in taps + [refused] {
            await tap.value
        }
        #expect(flow.photoSet.count == 2)
        #expect(flow.canShoot == false)
        flow.photoSet.discard()
    }

    @Test("A photo that fails on its way gives its place back")
    func failedPhotoGivesItsPlaceBack() async {
        let flow = harness.makeFlow(limit: .maximum(1))
        await flow.camera.start()
        let taps = await tap(flow, times: 1)
        #expect(flow.canShoot == false)
        harness.service.captureError = .captureFailed("The sensor gave nothing")
        harness.service.releaseHeldCalls()
        for tap in taps {
            await tap.value
        }
        #expect(flow.photoSet.isEmpty)
        #expect(flow.camera.photosInFlight == 0)
        #expect(flow.canShoot)
    }

    @Test("A running countdown keeps the shutter for the tap that stops it, though its photo would fill the set")
    func countdownKeepsTheShutter() async {
        var state = CameraFlowInitialState()
        state.timer.value = .threeSeconds
        let flow = harness.makeFlow(limit: .maximum(1), initialState: state)
        await flow.camera.start()
        let capturing = Task { await flow.camera.capture() }
        await harness.clock.waitForSleepers()
        #expect(flow.camera.photosInFlight == 1)
        #expect(flow.canShoot)
        await flow.camera.capture()
        await capturing.value
        #expect(flow.camera.photosInFlight == 0)
        #expect(flow.canShoot)
        #expect(harness.service.captureRequests.isEmpty)
    }

    @Test("The review, the check mark and the library wait until the last photo on its way has arrived")
    func flowWaitsForEveryPhoto() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 1)
        let taps = await tap(flow, times: 2)
        harness.service.releaseHeldCapture(at: 0)
        await taps[0].value
        #expect(flow.photoSet.count == 2)
        #expect(flow.canShowReview == false)
        #expect(flow.canAccept == false)
        #expect(flow.canOpenLibrary == false)
        harness.service.releaseHeldCalls()
        await taps[1].value
        #expect(flow.photoSet.count == 3)
        #expect(flow.canShowReview)
        #expect(flow.canAccept)
        #expect(flow.canOpenLibrary)
        flow.photoSet.discard()
    }

    @Test("A flow that ends after one photo takes one photo however quickly the shutter is pressed again")
    func endsAfterOnePhoto() async throws {
        let flow = harness.makeFlow(limit: .maximum(1), completion: .afterOnePhoto)
        await flow.camera.start()
        let taps = await tap(flow, times: 1)
        #expect(flow.canShoot == false)
        harness.service.holdsCalls = false
        let refused = Task { await flow.camera.capture() }
        await settleQueuedWork()
        #expect(harness.service.captureRequests.count == 1)
        harness.service.releaseHeldCalls()
        for tap in taps + [refused] {
            await tap.value
        }
        await settle { harness.outcome.handedOver.count == 1 }
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.count == 1)
        #expect(flow.photoSet.hasEnded)
        try FlowTestSupport.discardFiles(of: handedOver)
    }
}
