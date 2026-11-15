//
//  OnboardingLocationStepTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation
import Testing
@_spi(Testing) @testable import CameraFlow

/// One flow of the matrix: how the app configured the location and the introduction, whether it passes its own
/// location, and what the user answered about the location before.
struct LocationStepCase: Sendable, CustomTestStringConvertible {
    enum Variant: String, Sendable, CaseIterable {
        /// The introduction on, the flow asks.
        case automatic
        /// The introduction off.
        case onboardingOff
        /// The app asks for the location itself.
        case appRequestsAccess
        /// The photos record no location.
        case locationOff
    }

    let variant: Variant
    let hasProvider: Bool
    let authorization: LocationAuthorization

    static let all = Variant.allCases.flatMap { variant in
        [false, true].flatMap { hasProvider in
            [LocationAuthorization.notDetermined, .authorized, .denied, .restricted].map { authorization in
                Self(variant: variant, hasProvider: hasProvider, authorization: authorization)
            }
        }
    }

    var configuration: CameraFlowConfiguration {
        var configuration = CameraFlowConfiguration()
        switch variant {
        case .automatic: break
        case .onboardingOff: configuration.onboarding = .off
        case .appRequestsAccess: configuration.photoLocation = .appRequestsAccess
        case .locationOff: configuration.photoLocation = .off
        }
        return configuration
    }

    /// Only an introduction the flow asks in, before the user answered, has the step. The app's own location
    /// changes nothing about it.
    var showsStep: Bool {
        variant == .automatic && authorization == .notDetermined
    }

    var testDescription: String {
        "\(variant.rawValue), \(hasProvider ? "the app's location" : "the flow's location"), \(authorization)"
    }
}

@MainActor
@Suite("The introduction asks for the location", .temporaryDirectory, .timeLimit(.minutes(1)))
struct OnboardingLocationStepTests {

    /// The location access a flow of the case asks through, as the composition hands it over, with `location` as
    /// the flow's own location.
    private func authorizer(for stepCase: LocationStepCase, location: FakeLocation) -> (any LocationAuthorizer)? {
        let plan = PhotoLocationPlan(
            configuration: stepCase.configuration,
            locationProvider: stepCase.hasProvider ? { nil } : nil,
            makeProvidedLocation: { ProvidedPhotoLocation($0) { .precise } },
            makeSystemLocation: { location },
            makeCompass: { _ in FakeHeading() }
        )
        return plan.authorizer
    }

    private func makeSaving(writer: FakePhotoLibraryWriter) -> PhotoLibrarySavingModel {
        CaptureTestSupport.makeLibrarySaving(isUserAdjustable: true, destination: .library, writer: writer)
    }

    private func makeCamera(
        service: RecordingCameraService,
        onboarding: OnboardingModel,
        location: FakeLocation? = nil
    ) -> PhotoCameraModel {
        PhotoCameraModel(
            service: service,
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            onboarding: onboarding,
            files: CaptureTestSupport.makeFileStore(),
            location: location
        ) { _ in }
    }

    // MARK: - Whether it is shown

    @Test(
        "The location step follows the granted camera only where the flow asks and the user has not answered",
        arguments: LocationStepCase.all
    )
    func presence(stepCase: LocationStepCase) async {
        let configuration = stepCase.configuration
        let location = FakeLocation(authorization: stepCase.authorization)
        let onboarding = OnboardingModel(
            setting: configuration.onboarding,
            service: RecordingCameraService.unasked(),
            location: authorizer(for: stepCase, location: location)
        )
        await onboarding.proceed()
        #expect(onboarding.step == (stepCase.showsStep ? .location : nil))
        #expect(location.requestCount == 0)
    }

    @Test("A camera granted before opens on the location step alone", arguments: LocationStepCase.all)
    func cameraGrantedBefore(stepCase: LocationStepCase) {
        let configuration = stepCase.configuration
        let location = FakeLocation(authorization: stepCase.authorization)
        let onboarding = OnboardingModel(
            setting: configuration.onboarding,
            service: RecordingCameraService(),
            location: authorizer(for: stepCase, location: location)
        )
        #expect(onboarding.step == (stepCase.showsStep ? .location : nil))
    }

    @Test("A camera refused before gets no location step", arguments: [CameraAuthorization.denied, .restricted])
    func cameraRefusedBefore(authorization: CameraAuthorization) async {
        let service = RecordingCameraService()
        service.authorization = authorization
        let location = FakeLocation()
        let onboarding = OnboardingModel(setting: .automatic, service: service, location: location)
        #expect(onboarding.step == nil)
        let camera = makeCamera(service: service, onboarding: onboarding)
        await camera.start()
        #expect(location.requestCount == 0)
    }

    @Test(
        "A camera refused at its step ends the introduction before the location",
        arguments: [CameraAuthorization.denied, .restricted]
    )
    func cameraRefusedAtItsStep(authorization: CameraAuthorization) async {
        let location = FakeLocation()
        let onboarding = OnboardingModel(
            setting: .automatic,
            service: RecordingCameraService.unasked(answering: authorization),
            location: location
        )
        await onboarding.proceed()
        #expect(onboarding.step == nil)
        #expect(location.requestCount == 0)
    }

    // MARK: - The order of the steps

    @Test("Camera, location and library follow one another, each asked for once at its Continue")
    func fullWalk() async {
        let service = RecordingCameraService.unasked()
        let location = FakeLocation()
        let writer = FakePhotoLibraryWriter()
        let onboarding = OnboardingModel(
            setting: .automatic,
            service: service,
            location: location,
            librarySaving: makeSaving(writer: writer)
        )
        let camera = makeCamera(service: service, onboarding: onboarding, location: location)
        let start = Task { await camera.start() }
        #expect(onboarding.step == .camera)

        await onboarding.proceed()
        await start.value
        #expect(onboarding.step == .location)
        #expect(location.requestCount == 0)
        #expect(writer.requestedAccess.isEmpty)

        await onboarding.proceed()
        #expect(onboarding.step == .photoLibrary(access: .addOnly, isSavingUserAdjustable: true))
        #expect(location.requestCount == 1)
        #expect(location.authorization == .authorized)
        #expect(writer.requestedAccess.isEmpty)

        await onboarding.proceed()
        #expect(onboarding.step == nil)
        #expect(writer.requestedAccess == [.addOnly])
        #expect(location.requestCount == 1)
    }

    @Test("The location step of a camera granted before is followed by the library step")
    func cameraGrantedBeforeWithLibrary() async {
        let writer = FakePhotoLibraryWriter()
        let location = FakeLocation()
        let onboarding = OnboardingModel(
            setting: .automatic,
            service: RecordingCameraService(),
            location: location,
            librarySaving: makeSaving(writer: writer)
        )
        #expect(onboarding.step == .location)
        await onboarding.proceed()
        #expect(onboarding.step == .photoLibrary(access: .addOnly, isSavingUserAdjustable: true))
        #expect(location.requestCount == 1)
        #expect(writer.requestedAccess.isEmpty)
        await onboarding.proceed()
        #expect(onboarding.step == nil)
        #expect(writer.requestedAccess == [.addOnly])
    }

    // MARK: - The answers

    @Test("Continue asks once, waits for the answer and moves on only then")
    func continueAsksOnce() async {
        let location = FakeLocation()
        location.holdsRequest = true
        let onboarding = OnboardingModel(setting: .automatic, service: RecordingCameraService(), location: location)
        let first = Task { await onboarding.proceed() }
        await settle { location.heldRequestCount == 1 }
        #expect(onboarding.isAsking)
        #expect(onboarding.step == .location)

        await onboarding.proceed()
        #expect(location.requestCount == 1)
        #expect(onboarding.step == .location)

        location.releaseHeldRequests()
        await first.value
        #expect(onboarding.isAsking == false)
        #expect(onboarding.step == nil)
        #expect(location.requestCount == 1)
    }

    @Test("A refused location goes on with the flow", arguments: [LocationAuthorization.denied, .restricted])
    func refused(answer: LocationAuthorization) async {
        let location = FakeLocation(answerOnRequest: answer)
        let writer = FakePhotoLibraryWriter()
        let onboarding = OnboardingModel(
            setting: .automatic,
            service: RecordingCameraService.unasked(),
            location: location,
            librarySaving: makeSaving(writer: writer)
        )
        await onboarding.proceed()
        await onboarding.proceed()
        #expect(location.authorization == answer)
        #expect(onboarding.step == .photoLibrary(access: .addOnly, isSavingUserAdjustable: true))
        await onboarding.proceed()
        #expect(onboarding.step == nil)
        #expect(location.requestCount == 1)
    }

    // MARK: - The camera and the location

    @Test("The camera is neither asked for nor started before its answer, and the location is not asked by it")
    func cameraWaits() async {
        let service = RecordingCameraService.unasked()
        let location = FakeLocation()
        let onboarding = OnboardingModel(setting: .automatic, service: service, location: location)
        let camera = makeCamera(service: service, onboarding: onboarding, location: location)
        let start = Task { await camera.start() }
        await settleQueuedWork()
        #expect(service.authorizationRequestCount == 0)
        #expect(service.calls.isEmpty)
        #expect(location.followCalls.isEmpty)

        await onboarding.proceed()
        await start.value
        #expect(service.calls == [.start(.back), .exposureBias(0)])
        #expect(onboarding.step == .location)
        #expect(location.requestCount == 0)
    }

    @Test(
        "Without the introduction the location is asked for once the camera is granted, and only before an answer",
        arguments: [LocationAuthorization.notDetermined, .authorized, .denied]
    )
    func withoutIntroduction(authorization: LocationAuthorization) async {
        let service = RecordingCameraService.unasked()
        let location = FakeLocation(authorization: authorization)
        let onboarding = OnboardingModel(setting: .off, service: service, location: location)
        let camera = makeCamera(service: service, onboarding: onboarding, location: location)
        #expect(onboarding.step == nil)
        await camera.start()
        #expect(service.authorizationRequestCount == 1)
        #expect(location.requestCount == (authorization == .notDetermined ? 1 : 0))
    }

    @Test("Without the introduction a refused camera brings no location request")
    func withoutIntroductionRefused() async {
        let service = RecordingCameraService.unasked(answering: .denied)
        let location = FakeLocation()
        let onboarding = OnboardingModel(setting: .off, service: service, location: location)
        await makeCamera(service: service, onboarding: onboarding, location: location).start()
        #expect(location.requestCount == 0)
    }
}
