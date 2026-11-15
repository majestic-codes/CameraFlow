//
//  CameraFlowModelTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("Camera flow", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraFlowModelTests {
    let harness = FlowHarness()

    // MARK: - What is enabled

    @Test("An empty set shoots and opens the library, and has nothing to review or accept")
    func emptySet() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 0)
        #expect(flow.mode == .shooting)
        #expect(flow.canShoot)
        #expect(flow.canOpenLibrary)
        #expect(flow.canShowReview == false)
        #expect(flow.canAccept == false)
        #expect(flow.review.currentPhoto == nil)
    }

    @Test("A set with photos can be reviewed and accepted")
    func setWithPhotos() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 2)
        #expect(flow.canShowReview)
        #expect(flow.canAccept)
        #expect(flow.canShoot)
        #expect(flow.canOpenLibrary)
        flow.photoSet.discard()
    }

    @Test("A camera that has failed stops the shutter, and a retry that starts it brings the shutter back")
    func failedCamera() async {
        let flow = harness.makeFlow()
        harness.service.startError = .cannotUseCamera("Busy")
        await flow.camera.start()
        #expect(flow.camera.session.failure == .unavailable(.cannotUseCamera("Busy")))
        #expect(flow.canShoot == false)
        harness.service.startError = nil
        await flow.camera.retry()
        #expect(flow.camera.session.failure == nil)
        #expect(flow.canShoot)
    }

    @Test("A full set stops the shutter and the library, and stays reviewable and acceptable")
    func fullSet() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 2, limit: .maximum(2))
        #expect(flow.canShoot == false)
        #expect(flow.canOpenLibrary == false)
        #expect(flow.canShowReview)
        #expect(flow.canAccept)
        flow.photoSet.discard()
    }

    @Test("While a photo is being taken, the review, the hand-over and the library wait for it")
    func capturing() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 1)
        harness.service.holdsCalls = true
        let capturing = Task { await flow.camera.capture() }
        await settle { harness.service.heldCallCount == 1 }
        #expect(flow.canShowReview == false)
        #expect(flow.canAccept == false)
        #expect(flow.canOpenLibrary == false)
        flow.showReview()
        await flow.accept()
        flow.openLibrary()
        #expect(flow.mode == .shooting)
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(flow.isLibraryPresented == false)
        harness.service.releaseHeldCalls()
        await capturing.value
        #expect(flow.canShowReview)
        #expect(flow.canAccept)
        #expect(flow.canOpenLibrary)
        flow.photoSet.discard()
    }

    @Test("While picks load, the hand-over and the library wait for them, and the shutter goes on")
    func importing() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 1)
        let gate = CallGate()
        let data = try FlowTestSupport.makeJPEG()
        let importing = Task { await flow.photoSet.importPicks([FakeLibraryPick(data: data, gate: gate)]) }
        await gate.arrival()
        #expect(flow.canAccept == false)
        #expect(flow.canOpenLibrary == false)
        #expect(flow.canShoot)
        #expect(flow.canShowReview)
        await gate.open()
        await importing.value
        #expect(flow.canAccept)
        #expect(flow.canOpenLibrary)
        flow.photoSet.discard()
    }

    // MARK: - Photo library

    @Test("The library opens with what is left of the limit")
    func openLibrary() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 1, limit: .maximum(3))
        #expect(flow.librarySelectionLimit == 2)
        flow.openLibrary()
        #expect(flow.isLibraryPresented)
        flow.photoSet.discard()
    }

    @Test("A flow without a limit lets the library pick any number")
    func unlimitedLibrary() {
        #expect(harness.makeFlow().librarySelectionLimit == nil)
    }

    @Test("A flow without the photo library never opens it")
    func libraryOff() {
        let flow = harness.makeFlow(isLibraryPickerEnabled: false)
        #expect(flow.canOpenLibrary == false)
        flow.openLibrary()
        #expect(flow.isLibraryPresented == false)
    }

    // MARK: - Modes

    @Test("The review opens on the last photo added and stops the camera")
    func showReview() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 2)
        try await harness.importLibraryPhoto(into: flow)
        flow.showReview()
        #expect(flow.mode == .review)
        #expect(flow.review.currentPhoto?.id == flow.photoSet.photos.last?.id)
        #expect(flow.review.currentPhoto?.source == .photoLibrary)
        #expect(harness.service.calls.last == .stop)
        flow.photoSet.discard()
    }

    @Test("The review does not open on an empty set")
    func noReviewOfEmptySet() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 0)
        flow.showReview()
        #expect(flow.mode == .shooting)
        #expect(harness.service.calls.contains(.stop) == false)
    }

    @Test("Choosing the other mode on the switch changes the mode with one tick")
    func selectChangesMode() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 1)
        harness.haptics.removeAll()
        await flow.select(.review)
        #expect(flow.mode == .review)
        await flow.select(.review)
        #expect(harness.haptics.events == [.modeSelected])
        await flow.select(.shooting)
        #expect(flow.mode == .shooting)
        #expect(harness.haptics.events == [.modeSelected, .modeSelected])
        flow.photoSet.discard()
    }

    @Test("Choosing the review of an empty set is refused with a light haptic")
    func selectRefusedOnEmptySet() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 0)
        harness.haptics.removeAll()
        await flow.select(.review)
        #expect(flow.mode == .shooting)
        #expect(harness.haptics.events == [.modeRefused])
    }

    @Test("Returning to the camera starts it again on the same side, at the same zoom, with its settings")
    func showShooting() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 0)
        await flow.camera.flipCamera()
        flow.camera.zoom.setZoom(2)
        flow.camera.settings.cycleFlash()
        let flashMode = flow.camera.settings.flashMode
        await flow.camera.capture()
        flow.showReview()
        let callsBefore = harness.service.calls.count
        await flow.showShooting()
        #expect(flow.mode == .shooting)
        #expect(Array(harness.service.calls.dropFirst(callsBefore)) == [.start(.front), .exposureBias(0), .setZoom(2)])
        #expect(flow.camera.session.position == .front)
        #expect(flow.camera.zoom.factor == 2)
        #expect(flow.camera.settings.flashMode == flashMode)
        flow.photoSet.discard()
    }

    @Test("Returning to the camera drops the pictures the review prepared")
    func showShootingReleasesImages() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 1)
        let photo = try #require(flow.photoSet.photos.first)
        await flow.review.images.prepare([photo], maximumPixelSize: 20)
        try #require(flow.review.images.image(of: photo) !== photo.thumbnail)
        await flow.showShooting()
        #expect(flow.review.images.image(of: photo) === photo.thumbnail)
        flow.photoSet.discard()
    }

    @Test("A review opened again while the camera starts leaves the camera stopped")
    func reviewDuringRestart() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 1)
        flow.showReview()
        harness.service.holdsCalls = true
        let returning = Task { await flow.showShooting() }
        await settle { harness.service.heldCallCount == 1 }
        #expect(flow.mode == .shooting)
        flow.showReview()
        harness.service.releaseHeldCalls()
        await returning.value
        #expect(flow.mode == .review)
        #expect(harness.service.calls.last == .stop)
        flow.photoSet.discard()
    }

    @Test("The hardware buttons take photos only while the camera is what the user looks at")
    func captureButtons() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 1)
        #expect(flow.acceptsCaptureButtons)
        flow.openLibrary()
        #expect(flow.acceptsCaptureButtons == false)
        flow.isLibraryPresented = false
        flow.requestExit()
        #expect(flow.acceptsCaptureButtons == false)
        flow.cancelExit()
        #expect(flow.acceptsCaptureButtons)
        flow.showReview()
        #expect(flow.acceptsCaptureButtons == false)
        await flow.showShooting()
        #expect(flow.acceptsCaptureButtons)
        flow.photoSet.discard()
    }

    @Test("The hardware buttons take no photo under the introduction, with the camera running behind it")
    func captureButtonsUnderOnboarding() async {
        harness.service.isAuthorizationDetermined = false
        let saving = CaptureTestSupport.makeLibrarySaving()
        let onboarding = OnboardingModel(setting: .automatic, service: harness.service, librarySaving: saving)
        let flow = harness.makeFlow(librarySaving: saving, onboarding: onboarding)
        let camera = flow.camera
        let start = Task { await camera.start() }
        await settleQueuedWork()
        #expect(flow.acceptsCaptureButtons == false)
        await onboarding.proceed()
        await start.value
        #expect(onboarding.step != nil)
        #expect(camera.session.isRunning)
        #expect(flow.acceptsCaptureButtons == false)
        await onboarding.proceed()
        #expect(onboarding.step == nil)
        #expect(flow.acceptsCaptureButtons)
        flow.photoSet.discard()
    }

    @Test("The hardware buttons take no photo before the camera runs")
    func captureButtonsBeforeStart() {
        #expect(harness.makeFlow().acceptsCaptureButtons == false)
    }
}
