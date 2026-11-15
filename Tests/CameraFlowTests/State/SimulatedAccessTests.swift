//
//  SimulatedAccessTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("A flow over a simulated camera that refuses", .temporaryDirectory, .timeLimit(.minutes(1)))
struct SimulatedAccessTests {

    @Test("A simulated camera made to refuse says no when it is asked for, and its flow shows the failure")
    func simulatedCameraRefused() async {
        let service = SimulatedCameraService(
            scene: .black,
            isAuthorizationDetermined: false,
            authorizationOnRequest: .denied
        )
        #expect(service.isAuthorizationDetermined == false)
        let onboarding = OnboardingModel(setting: .automatic, service: service)
        let camera = PhotoCameraModel(
            service: service,
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            onboarding: onboarding,
            files: CaptureTestSupport.makeFileStore()
        ) { _ in }
        let start = Task { await camera.start() }
        await onboarding.proceed()
        await start.value
        #expect(service.isAuthorizationDetermined)
        #expect(onboarding.step == nil)
        #expect(camera.session.failure == .accessDenied)
        #expect(camera.session.capabilities == nil)
    }
}
