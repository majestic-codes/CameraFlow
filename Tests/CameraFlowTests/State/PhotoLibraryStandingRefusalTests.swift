//
//  PhotoLibraryStandingRefusalTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

/// A photo library that refused the flow before it opened, and a refusal that comes while the camera starts: the
/// screen says it from the start and keeps saying it until the user goes on.
@MainActor
@Suite("A photo library refused before the first save", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoLibraryStandingRefusalTests {

    @Test(
        "Saving that opens on over a refused library goes off where the user may switch it, and says why at once",
        arguments: [
            (
                PhotoLibraryAuthorization.denied,
                CameraFlowPhotoLibrarySaving.Destination.library,
                CameraFlowPhotoLibrarySaveFailure.accessDenied
            ),
            (.restricted, .library, .accessRestricted),
            (.limited, .album(named: "Field"), .limitedAccess)
        ]
    )
    func adjustableSaving(
        authorization: PhotoLibraryAuthorization,
        destination: CameraFlowPhotoLibrarySaving.Destination,
        failure: CameraFlowPhotoLibrarySaveFailure
    ) async {
        let writer = FakePhotoLibraryWriter(authorization: authorization)
        let saving = CaptureTestSupport.makeLibrarySaving(destination: destination, writer: writer)
        var reported: [CameraFlowPreferences] = []
        let flow = FlowHarness().makeFlow(librarySaving: saving) { reported.append($0) }
        await flow.camera.start()
        #expect(flow.camera.settings.isLibrarySavingOn == false)
        #expect(flow.camera.notice == .librarySavingRefused(failure))
        #expect(writer.requestedAccess.isEmpty)
        #expect(reported.isEmpty)
    }

    @Test("Saving the app fixed on stays on over a refused library, and says why at once")
    func fixedSaving() async {
        let writer = FakePhotoLibraryWriter(authorization: .denied)
        let saving = CaptureTestSupport.makeLibrarySaving(isUserAdjustable: false, writer: writer)
        let flow = FlowHarness().makeFlow(librarySaving: saving)
        await flow.camera.start()
        #expect(saving.isOn)
        #expect(flow.camera.notice == .librarySavingRefused(.accessDenied))
    }

    @Test("A library that has not been asked, or that granted the access, changes nothing at the opening")
    func answeredOrNot() async {
        for authorization in [PhotoLibraryAuthorization.notDetermined, .authorized, .limited] {
            let writer = FakePhotoLibraryWriter(authorization: authorization)
            let saving = CaptureTestSupport.makeLibrarySaving(writer: writer)
            let flow = FlowHarness().makeFlow(librarySaving: saving)
            await flow.camera.start()
            #expect(saving.isOn)
            #expect(flow.camera.notice == nil)
            #expect(writer.requestedAccess.isEmpty)
        }
    }

    @Test("A refusal the introduction got while the camera was starting outlasts the start")
    func refusalWhileStarting() async {
        let service = RecordingCameraService()
        let writer = FakePhotoLibraryWriter(grantedOnRequest: .denied)
        let saving = CaptureTestSupport.makeLibrarySaving(writer: writer)
        let onboarding = OnboardingModel(setting: .automatic, service: service, librarySaving: saving)
        #expect(onboarding.step == .photoLibrary(access: .addOnly, isSavingUserAdjustable: true))
        let camera = PhotoCameraModel(
            service: service,
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            librarySaving: saving,
            onboarding: onboarding,
            files: CaptureTestSupport.makeFileStore()
        ) { _ in }
        service.holdsCalls = true
        let starting = Task { await camera.start() }
        await settle { service.heldCallCount == 1 }
        await onboarding.proceed()
        #expect(camera.notice == .librarySavingRefused(.accessDenied))
        service.holdsCalls = false
        service.releaseHeldCalls()
        await starting.value
        #expect(camera.session.capabilities != nil)
        #expect(camera.notice == .librarySavingRefused(.accessDenied))
        camera.settings.cycleFlash()
        #expect(camera.notice == nil)
    }
}
