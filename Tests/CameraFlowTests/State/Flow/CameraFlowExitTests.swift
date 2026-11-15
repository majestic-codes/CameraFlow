//
//  CameraFlowExitTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("Camera flow: the ways out", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraFlowExitTests {
    let harness = FlowHarness()

    @Test("The check mark hands the set over once, and the cross does nothing after it")
    func accept() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 2)
        try await harness.importLibraryPhoto(into: flow)
        let identifiers = flow.photoSet.photos.map(\.id)
        await flow.accept()
        await flow.accept()
        flow.requestExit()
        flow.confirmExit()
        try #require(harness.outcome.handedOver.count == 1)
        #expect(harness.outcome.handedOver[0].map(\.id) == identifiers)
        #expect(harness.outcome.exitCount == 0)
        #expect(flow.exitConfirmation == nil)
        try FlowTestSupport.discardFiles(of: harness.outcome.handedOver[0])
    }

    @Test(
        "A flow whose camera cannot run takes no photo, and still opens the library and closes",
        arguments: [CameraFailure.unavailable(.noCamera), .accessDenied, .accessRestricted]
    )
    func cameraThatCannotRun(failure: CameraFailure) async {
        switch failure {
        case .accessDenied: harness.service.authorization = .denied
        case .accessRestricted: harness.service.authorization = .restricted
        case .unavailable, .stopped: harness.service.startError = .noCamera
        }
        let flow = harness.makeFlow()
        await flow.camera.start()
        #expect(flow.camera.session.failure == failure)
        #expect(flow.acceptsCaptureButtons == false)
        await flow.camera.capture()
        #expect(harness.service.captureRequests.isEmpty)
        #expect(flow.photoSet.isEmpty)
        #expect(flow.canOpenLibrary)
        flow.openLibrary()
        #expect(flow.isLibraryPresented)
        flow.isLibraryPresented = false
        flow.requestExit()
        #expect(harness.outcome.exitCount == 1)
    }

    @Test("The check mark does nothing on an empty set")
    func acceptEmptySet() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 0)
        await flow.accept()
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(flow.photoSet.hasEnded == false)
    }

    @Test("The cross leaves an empty set at once, and only once")
    func exitEmptySet() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 0)
        flow.requestExit()
        flow.requestExit()
        #expect(flow.exitConfirmation == nil)
        #expect(harness.outcome.exitCount == 1)
        #expect(flow.photoSet.hasEnded)
    }

    @Test("The cross asks before it leaves a set with camera photos")
    func exitAsksAboutCameraPhotos() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 2)
        try await harness.importLibraryPhoto(into: flow)
        flow.requestExit()
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 3, hasCameraPhotos: true))
        #expect(harness.outcome.exitCount == 0)
        #expect(flow.photoSet.count == 3)
        flow.photoSet.discard()
    }

    @Test("The cross asks before it leaves a set of library photos, which survive in the library")
    func exitAsksAboutLibraryPhotos() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 0)
        try await harness.importLibraryPhoto(into: flow)
        flow.requestExit()
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 1, hasCameraPhotos: false))
        flow.photoSet.discard()
    }

    @Test("The exit alert counts the photos that land while it is up")
    func exitCountsLatePhotos() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 0)
        try await harness.importLibraryPhoto(into: flow)
        flow.requestExit()
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 1, hasCameraPhotos: false))
        await flow.camera.capture()
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 2, hasCameraPhotos: true))
        let message = "The set has 2 photos. The ones taken with the camera will be gone for good."
        #expect(try FlowText(.system).exitMessage(for: #require(flow.exitConfirmation)) == message)
        let photos = flow.photoSet.photos
        flow.confirmExit()
        #expect(flow.exitConfirmation == nil)
        expectDeleted(photos)
    }

    @Test("Once the set is handed over the camera is stopped and takes no photo, though the flow stays on screen")
    func flowLeftOnScreenAfterHandOver() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 1)
        #expect(flow.canShoot)
        await flow.accept()
        #expect(harness.service.calls.last == .stop)
        #expect(flow.camera.delivery.isClosed)
        #expect(flow.canShoot == false)
        #expect(flow.acceptsCaptureButtons == false)
        #expect(flow.canOpenLibrary == false)
        let handedOver = try #require(harness.outcome.handedOver.first)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A flow that was left takes no photo either")
    func flowLeftOnScreenAfterExit() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 0)
        flow.requestExit()
        #expect(flow.canShoot == false)
        #expect(flow.acceptsCaptureButtons == false)
    }

    @Test("Staying keeps the set")
    func cancelExit() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 1)
        flow.requestExit()
        flow.cancelExit()
        #expect(flow.exitConfirmation == nil)
        #expect(harness.outcome.exitCount == 0)
        #expect(flow.photoSet.count == 1)
        #expect(flow.canAccept)
        flow.photoSet.discard()
    }

    @Test("Leaving deletes the set and tells the app once")
    func confirmExit() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 1)
        try await harness.importLibraryPhoto(into: flow)
        let photos = flow.photoSet.photos
        flow.requestExit()
        flow.confirmExit()
        flow.confirmExit()
        #expect(flow.exitConfirmation == nil)
        #expect(harness.outcome.exitCount == 1)
        #expect(harness.outcome.handedOver.isEmpty)
        expectDeleted(photos)
        #expect(FlowTestSupport.fileExists(harness.files.directory) == false)
    }
}
