//
//  OnboardingModelTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("The introduction before the camera is asked for", .temporaryDirectory, .timeLimit(.minutes(1)))
struct OnboardingModelTests {

    /// The saving of a flow that opens with it on, into the library (add-only access) or an album (read-write).
    private func makeSaving(
        access: PhotoLibraryAccess = .addOnly,
        isSavingUserAdjustable: Bool = true,
        writer: FakePhotoLibraryWriter = FakePhotoLibraryWriter()
    ) -> PhotoLibrarySavingModel {
        CaptureTestSupport.makeLibrarySaving(
            isUserAdjustable: isSavingUserAdjustable,
            destination: access == .addOnly ? .library : .album(named: "Field photos"),
            writer: writer
        )
    }

    private func makeCamera(service: RecordingCameraService, onboarding: OnboardingModel) -> PhotoCameraModel {
        PhotoCameraModel(
            service: service,
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            onboarding: onboarding,
            files: CaptureTestSupport.makeFileStore()
        ) { _ in }
    }

    // MARK: - A wait that is cancelled

    @Test("A start cancelled during the camera step leaves the next start waiting for Continue")
    func cancelledWaitKeepsTheStep() async {
        let service = RecordingCameraService.unasked()
        let onboarding = OnboardingModel(setting: .automatic, service: service)
        let camera = makeCamera(service: service, onboarding: onboarding)
        let firstStart = Task { await camera.start() }
        await Self.yieldForAWhile()
        firstStart.cancel()
        await firstStart.value

        let secondStart = Task { await camera.start() }
        await Self.yieldForAWhile()
        #expect(service.authorizationRequestCount == 0)
        #expect(onboarding.step == .camera)
        await onboarding.proceed()
        #expect(service.authorizationRequestCount == 1)
        await secondStart.value
        #expect(onboarding.step != .camera)
        #expect(camera.session.capabilities != nil)
    }

    /// Lets the tasks that wait on the main actor run for a while.
    private static func yieldForAWhile() async {
        for _ in 0..<50 {
            await Task.yield()
        }
    }

    // MARK: - Whether it is shown

    @Test("A flow opened before the camera was asked for shows the camera step")
    func cameraNotAsked() {
        let onboarding = OnboardingModel(setting: .automatic, service: RecordingCameraService.unasked())
        #expect(onboarding.step == .camera)
        #expect(onboarding.isAsking == false)
    }

    @Test(
        "A camera that already has an answer gets no camera step, and a granted one opens on the library step",
        arguments: [CameraAuthorization.authorized, .denied, .restricted]
    )
    func cameraAnswered(authorization: CameraAuthorization) async {
        let service = RecordingCameraService()
        service.authorization = authorization
        let onboarding = OnboardingModel(setting: .automatic, service: service, librarySaving: makeSaving())
        let libraryStep = OnboardingStep.photoLibrary(access: .addOnly, isSavingUserAdjustable: true)
        #expect(onboarding.step == (authorization == .authorized ? libraryStep : nil))
        await onboarding.waitForCameraStep()
        #expect(service.authorizationRequestCount == 0)
    }

    @Test("A flow with the introduction off has no step, and its camera is asked for as soon as it starts")
    func off() async {
        let service = RecordingCameraService.unasked()
        let onboarding = OnboardingModel(setting: .off, service: service, librarySaving: makeSaving())
        let camera = makeCamera(service: service, onboarding: onboarding)
        #expect(onboarding.step == nil)
        await camera.start()
        #expect(service.authorizationRequestCount == 1)
        #expect(service.calls == [.start(.back), .exposureBias(0)])
    }

    @Test("A camera model made without an introduction asks for the camera as soon as it starts")
    func defaultCameraModel() async {
        let service = RecordingCameraService.unasked()
        let camera = makeCaptureModel(service: service)
        #expect(camera.onboarding.step == nil)
        await camera.start()
        #expect(service.calls == [.start(.back), .exposureBias(0)])
    }

    @Test("A device with no camera gets no introduction")
    func noCamera() {
        let service = RecordingCameraService.unasked()
        service.cameraPositions = []
        let onboarding = OnboardingModel(setting: .automatic, service: service)
        #expect(onboarding.step == nil)
    }

    // MARK: - The camera step

    @Test("The camera is neither asked for nor started until Continue, and starts once it is granted")
    func cameraWaitsForContinue() async {
        let service = RecordingCameraService.unasked()
        let onboarding = OnboardingModel(setting: .automatic, service: service)
        let camera = makeCamera(service: service, onboarding: onboarding)
        let start = Task { await camera.start() }
        await settleQueuedWork()
        #expect(service.authorizationRequestCount == 0)
        #expect(service.calls.isEmpty)

        await onboarding.proceed()
        await start.value
        #expect(onboarding.step == nil)
        #expect(service.calls == [.start(.back), .exposureBias(0)])
        #expect(camera.session.failure == nil)
        #expect(camera.session.capabilities != nil)
    }

    @Test("The camera's first start after the introduction covers no picture, through the library step too")
    func firstStartUncovered() async {
        let service = RecordingCameraService.unasked()
        let onboarding = OnboardingModel(setting: .automatic, service: service, librarySaving: makeSaving())
        let camera = makeCamera(service: service, onboarding: onboarding)
        let cover = RecordingPictureCover(countingCallsOf: service)
        camera.session.pictureCovers.add(cover)
        let start = Task { await camera.start() }
        await onboarding.proceed()
        await start.value
        await onboarding.proceed()
        #expect(onboarding.step == nil)
        #expect(camera.session.capabilities != nil)
        #expect(cover.events.isEmpty)
    }

    @Test(
        "A camera refused at the request ends the introduction with the camera's own failure, library unasked",
        arguments: [
            (CameraAuthorization.denied, CameraFailure.accessDenied),
            (.restricted, .accessRestricted)
        ]
    )
    func cameraRefused(authorization: CameraAuthorization, failure: CameraFailure) async {
        let service = RecordingCameraService.unasked(answering: authorization)
        let writer = FakePhotoLibraryWriter()
        let saving = makeSaving(writer: writer)
        let onboarding = OnboardingModel(setting: .automatic, service: service, librarySaving: saving)
        let camera = makeCamera(service: service, onboarding: onboarding)
        let start = Task { await camera.start() }
        await onboarding.proceed()
        await start.value
        #expect(onboarding.step == nil)
        #expect(camera.session.failure == failure)
        #expect(service.calls.isEmpty)
        #expect(writer.requestedAccess.isEmpty)
    }

    @Test("A second Continue while the system's request is up asks nothing more")
    func continueWhileAsking() async {
        let service = RecordingCameraService.unasked()
        service.holdsAuthorization = true
        let onboarding = OnboardingModel(setting: .automatic, service: service)
        let first = Task { await onboarding.proceed() }
        await settle { service.heldCallCount == 1 }
        #expect(onboarding.isAsking)
        await onboarding.proceed()
        #expect(service.authorizationRequestCount == 1)
        #expect(onboarding.step == .camera)

        service.releaseHeldCalls()
        await first.value
        #expect(onboarding.isAsking == false)
        #expect(onboarding.step == nil)
    }

    @Test("A flow closed during the camera step never asks for the camera")
    func closedDuringCameraStep() async {
        let service = RecordingCameraService.unasked()
        let onboarding = OnboardingModel(setting: .automatic, service: service)
        let camera = makeCamera(service: service, onboarding: onboarding)
        let start = Task { await camera.start() }
        await settleQueuedWork()
        start.cancel()
        await start.value
        #expect(service.authorizationRequestCount == 0)
        #expect(service.calls.isEmpty)
        #expect(onboarding.step == .camera)
    }

    // MARK: - The photo library step

    @Test(
        "A granted camera is followed by the library step of a flow that opens saving, with the access it needs",
        arguments: [
            (PhotoLibraryAccess.addOnly, true),
            (.addOnly, false),
            (.readWrite, true)
        ]
    )
    func libraryStep(access: PhotoLibraryAccess, isSavingUserAdjustable: Bool) async {
        let service = RecordingCameraService.unasked()
        let writer = FakePhotoLibraryWriter()
        let saving = makeSaving(access: access, isSavingUserAdjustable: isSavingUserAdjustable, writer: writer)
        let onboarding = OnboardingModel(setting: .automatic, service: service, librarySaving: saving)
        let camera = makeCamera(service: service, onboarding: onboarding)
        let start = Task { await camera.start() }
        await onboarding.proceed()
        await start.value
        #expect(onboarding.step == .photoLibrary(access: access, isSavingUserAdjustable: isSavingUserAdjustable))
        #expect(service.calls == [.start(.back), .exposureBias(0)])
        #expect(writer.requestedAccess.isEmpty)

        await onboarding.proceed()
        #expect(onboarding.step == nil)
        #expect(writer.requestedAccess == [access])
    }

    @Test("A flow that never saves has no library step")
    func noSaving() async {
        let onboarding = OnboardingModel(setting: .automatic, service: RecordingCameraService.unasked())
        await onboarding.proceed()
        #expect(onboarding.step == nil)
    }

    @Test(
        "A library that already has an answer is not asked for again",
        arguments: [PhotoLibraryAuthorization.authorized, .limited, .denied, .restricted]
    )
    func libraryAnswered(authorization: PhotoLibraryAuthorization) async {
        let writer = FakePhotoLibraryWriter(authorization: authorization)
        let saving = makeSaving(writer: writer)
        let onboarding = OnboardingModel(
            setting: .automatic,
            service: RecordingCameraService.unasked(),
            librarySaving: saving
        )
        await onboarding.proceed()
        #expect(onboarding.step == nil)
        #expect(writer.requestedAccess.isEmpty)
    }

    @Test("A refused library ends the introduction all the same")
    func libraryRefused() async {
        let writer = FakePhotoLibraryWriter(grantedOnRequest: .denied)
        let saving = makeSaving(writer: writer)
        let onboarding = OnboardingModel(
            setting: .automatic,
            service: RecordingCameraService.unasked(),
            librarySaving: saving
        )
        await onboarding.proceed()
        await onboarding.proceed()
        #expect(onboarding.step == nil)
        #expect(writer.requestedAccess == [.addOnly])
    }
}
