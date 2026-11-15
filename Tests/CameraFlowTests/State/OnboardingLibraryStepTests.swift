//
//  OnboardingLibraryStepTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

/// The saving of a flow as the app set it and as the user left it, and whether the introduction asks for the
/// photo library.
struct OpeningSavingCase: Sendable, CustomTestStringConvertible {
    let isEnabled: CameraFlowSetting<Bool>
    /// The preferences the app stored, with nothing chosen when it stored none.
    var appPreferences = CameraFlowPreferences()
    /// The preferences the flow remembers, with nothing chosen when it remembers none.
    var remembered = CameraFlowPreferences()
    let asksForLibrary: Bool

    static let all = [
        Self(isEnabled: CameraFlowSetting(false), asksForLibrary: false),
        Self(isEnabled: CameraFlowSetting(true), asksForLibrary: true),
        Self(isEnabled: CameraFlowSetting(false), appPreferences: .saving(true), asksForLibrary: true),
        Self(isEnabled: CameraFlowSetting(false), remembered: .saving(true), asksForLibrary: true),
        Self(isEnabled: CameraFlowSetting(true), appPreferences: .saving(false), asksForLibrary: false),
        Self(isEnabled: CameraFlowSetting(true), remembered: .saving(false), asksForLibrary: false),
        Self(
            isEnabled: CameraFlowSetting(true),
            appPreferences: .saving(false),
            remembered: .saving(true),
            asksForLibrary: false
        ),
        Self(
            isEnabled: CameraFlowSetting(false),
            appPreferences: .saving(true),
            remembered: .saving(false),
            asksForLibrary: true
        ),
        Self(isEnabled: .fixed(true), appPreferences: .saving(false), remembered: .saving(false), asksForLibrary: true),
        Self(isEnabled: .fixed(false), appPreferences: .saving(true), remembered: .saving(true), asksForLibrary: false)
    ]

    var testDescription: String {
        let kind = isEnabled.isUserAdjustable ? "a switch" : "fixed"
        let position = isEnabled.value ? "on" : "off"
        let preference = Self.describe(appPreferences, as: "the app stored") ?? "nothing stored by the app"
        let memory = Self.describe(remembered, as: "the flow remembers") ?? "nothing remembered"
        return "\(kind) \(position), \(preference), \(memory)"
    }

    /// The saving the preferences hold, after the words of who holds them, nil when they hold none.
    private static func describe(_ preferences: CameraFlowPreferences, as holder: String) -> String? {
        preferences.isPhotoLibrarySavingEnabled.map { "\(holder) \($0 ? "on" : "off")" }
    }
}

private extension CameraFlowPreferences {

    /// Preferences that hold only whether the photos are saved to the photo library.
    static func saving(_ isEnabled: Bool) -> Self {
        var preferences = Self()
        preferences.isPhotoLibrarySavingEnabled = isEnabled
        return preferences
    }
}

/// One flow of the presence matrix of the library step: the introduction, how the camera was answered, whether the
/// location step is due, how saving opens and whether the library was answered before.
struct LibraryStepPresenceCase: Sendable, CustomTestStringConvertible {
    enum Camera: String, Sendable, CaseIterable {
        case grantedAtItsStep
        case refusedAtItsStep
        case grantedBefore
        case refusedBefore
    }

    enum Saving: String, Sendable, CaseIterable {
        case opensOn
        case opensOff
        /// The flow never saves to the library.
        case never
    }

    let onboarding: CameraFlowOnboarding
    let camera: Camera
    let isLocationAnswered: Bool
    let saving: Saving
    let isLibraryAnswered: Bool

    static let all = [CameraFlowOnboarding.automatic, .off].flatMap { onboarding in
        Camera.allCases.flatMap { camera in
            [false, true].flatMap { isLocationAnswered in
                Saving.allCases.flatMap { saving in
                    [false, true].map { isLibraryAnswered in
                        Self(
                            onboarding: onboarding,
                            camera: camera,
                            isLocationAnswered: isLocationAnswered,
                            saving: saving,
                            isLibraryAnswered: isLibraryAnswered
                        )
                    }
                }
            }
        }
    }

    private var isCameraGranted: Bool {
        camera == .grantedAtItsStep || camera == .grantedBefore
    }

    /// The steps the introduction walks through when the user continues at each: camera, location, library, each
    /// where it is due.
    var expectedSteps: [OnboardingStep] {
        guard onboarding == .automatic else { return [] }
        var steps: [OnboardingStep] = []
        if camera == .grantedAtItsStep || camera == .refusedAtItsStep {
            steps.append(.camera)
        }
        guard isCameraGranted else { return steps }
        if !isLocationAnswered {
            steps.append(.location)
        }
        if saving == .opensOn, !isLibraryAnswered {
            steps.append(.photoLibrary(access: .addOnly, isSavingUserAdjustable: true))
        }
        return steps
    }

    var testDescription: String {
        let location = isLocationAnswered ? "location answered" : "location not asked"
        let library = isLibraryAnswered ? "library answered" : "library not asked"
        return "\(onboarding), camera \(camera.rawValue), \(location), saving \(saving.rawValue), \(library)"
    }
}

@MainActor
@Suite("The introduction asks for the photo library as saving opens", .temporaryDirectory, .timeLimit(.minutes(1)))
struct OnboardingLibraryStepTests {
    private let store = FakePreferenceStore()
    private let writer = FakePhotoLibraryWriter()

    /// The saving of a flow as it opens with the stored choices of the case, nil for a flow that never saves.
    private func makeSaving(for savingCase: OpeningSavingCase) -> PhotoLibrarySavingModel? {
        let memory = CaptureTestSupport.makeMemory(store: store)
        if savingCase.remembered != CameraFlowPreferences() {
            memory.store(savingCase.remembered)
        }
        let opening = UserChoices(preferences: savingCase.appPreferences, memory: memory, onChange: nil)
        var saving = CameraFlowPhotoLibrarySaving()
        saving.isEnabled = savingCase.isEnabled
        guard saving.isPossible else { return nil }
        return PhotoLibrarySavingModel(saving: saving, isOn: opening.opensLibrarySaving(saving), writer: writer)
    }

    @Test(
        "The library step follows a camera granted at its step only where saving opens on",
        arguments: OpeningSavingCase.all
    )
    func libraryStep(savingCase: OpeningSavingCase) async {
        let service = RecordingCameraService()
        service.isAuthorizationDetermined = false
        let saving = makeSaving(for: savingCase)
        let onboarding = OnboardingModel(setting: .automatic, service: service, librarySaving: saving)
        #expect(onboarding.step == .camera)
        await onboarding.proceed()
        let isSavingUserAdjustable = savingCase.isEnabled.isUserAdjustable
        let step = OnboardingStep.photoLibrary(access: .addOnly, isSavingUserAdjustable: isSavingUserAdjustable)
        #expect(onboarding.step == (savingCase.asksForLibrary ? step : nil))
        #expect(writer.requestedAccess.isEmpty)
    }

    @Test(
        "The library step comes after the camera and the location wherever the camera is granted and saving opens on",
        arguments: LibraryStepPresenceCase.all
    )
    func libraryStepPresence(presenceCase: LibraryStepPresenceCase) async {
        let service = RecordingCameraService()
        switch presenceCase.camera {
        case .grantedAtItsStep:
            service.isAuthorizationDetermined = false
        case .refusedAtItsStep:
            service.isAuthorizationDetermined = false
            service.authorization = .denied
        case .grantedBefore:
            break
        case .refusedBefore:
            service.authorization = .denied
        }
        let location = FakeLocation(authorization: presenceCase.isLocationAnswered ? .authorized : .notDetermined)
        let isLibraryAnswered = presenceCase.isLibraryAnswered
        let writer = FakePhotoLibraryWriter(authorization: isLibraryAnswered ? .authorized : .notDetermined)
        let saving: PhotoLibrarySavingModel? = switch presenceCase.saving {
        case .opensOn: CaptureTestSupport.makeLibrarySaving(isOn: true, writer: writer)
        case .opensOff: CaptureTestSupport.makeLibrarySaving(isOn: false, writer: writer)
        case .never: nil
        }
        let onboarding = OnboardingModel(
            setting: presenceCase.onboarding,
            service: service,
            location: location,
            librarySaving: saving
        )
        var walked: [OnboardingStep] = []
        while let step = onboarding.step, walked.count < 4 {
            walked.append(step)
            await onboarding.proceed()
        }
        #expect(walked == presenceCase.expectedSteps)
        let isLibraryAsked = presenceCase.expectedSteps.contains { step in
            if case .photoLibrary = step { true } else { false }
        }
        #expect(writer.requestedAccess == (isLibraryAsked ? [.addOnly] : []))
    }

    @Test("A switch that opens off asks for the library when the user switches it on, not in the introduction")
    func askedAtTheSwitch() async throws {
        let savingCase = OpeningSavingCase(isEnabled: CameraFlowSetting(false), asksForLibrary: false)
        let saving = try #require(makeSaving(for: savingCase))
        let service = RecordingCameraService()
        service.isAuthorizationDetermined = false
        let onboarding = OnboardingModel(setting: .automatic, service: service, librarySaving: saving)
        await onboarding.proceed()
        #expect(onboarding.step == nil)
        #expect(writer.requestedAccess.isEmpty)
        await saving.setOn(true)
        #expect(writer.requestedAccess == [.addOnly])
        #expect(saving.isOn)
    }

    // MARK: - The answer of the library

    @Test(
        "A refused library ends the introduction, turns a switch the user owns off and leaves a notice",
        arguments: [true, false]
    )
    func libraryRefused(isSavingUserAdjustable: Bool) async {
        let service = RecordingCameraService()
        service.isAuthorizationDetermined = false
        let writer = FakePhotoLibraryWriter(grantedOnRequest: .denied)
        let saving = CaptureTestSupport.makeLibrarySaving(isUserAdjustable: isSavingUserAdjustable, writer: writer)
        let onboarding = OnboardingModel(setting: .automatic, service: service, librarySaving: saving)
        var reported: [CameraFlowPreferences] = []
        let camera = PhotoCameraModel(
            service: service,
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            librarySaving: saving,
            onboarding: onboarding,
            files: CaptureTestSupport.makeFileStore(),
            onCapture: { _ in },
            onPreferencesChange: { reported.append($0) }
        )
        let start = Task { await camera.start() }
        await onboarding.proceed()
        await start.value
        await onboarding.proceed()
        #expect(onboarding.step == nil)
        #expect(writer.requestedAccess == [.addOnly])
        #expect(saving.isOn == !isSavingUserAdjustable)
        #expect(camera.settings.isLibrarySavingOn == !isSavingUserAdjustable)
        #expect(saving.refusal == .accessDenied)
        #expect(camera.notice == .librarySavingRefused(.accessDenied))
        #expect(reported.isEmpty)
    }

    @Test("A granted library leaves saving on and says nothing")
    func libraryGranted() async {
        let service = RecordingCameraService()
        service.isAuthorizationDetermined = false
        let saving = CaptureTestSupport.makeLibrarySaving(writer: writer)
        let onboarding = OnboardingModel(setting: .automatic, service: service, librarySaving: saving)
        let camera = PhotoCameraModel(
            service: service,
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            librarySaving: saving,
            onboarding: onboarding,
            files: CaptureTestSupport.makeFileStore()
        ) { _ in }
        let start = Task { await camera.start() }
        await onboarding.proceed()
        await start.value
        await onboarding.proceed()
        #expect(saving.isOn)
        #expect(saving.refusal == nil)
        #expect(camera.notice == nil)
        #expect(writer.requestedAccess == [.addOnly])
    }
}
