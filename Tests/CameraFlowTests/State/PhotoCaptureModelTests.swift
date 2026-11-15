//
//  PhotoCaptureModelTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("Photo capture through the model", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoCaptureModelTests {
    // MARK: - Overlap and failures

    @Test("A shutter tap while a photo is on its way takes another photo, as the stock camera does")
    func overlappingCaptures() async throws {
        let service = RecordingCameraService()
        var photos: [CameraCapture] = []
        let model = makeCaptureModel(service: service) { photos.append($0) }
        await model.start()
        service.holdsCalls = true
        let firstCapture = Task { await model.capture() }
        await settle { service.heldCallCount == 1 }
        let secondCapture = Task { await model.capture() }
        await settle { service.heldCallCount == 2 }
        await service.releaseHeldCaptures(inTurn: 2)
        await firstCapture.value
        await secondCapture.value
        #expect(service.captureRequests.count == 2)
        #expect(model.shutter.captureCount == 2)
        #expect(photos.count == 2)
        try photos.forEach(CaptureTestSupport.discardFiles)
    }

    @Test("A photo that cannot be processed is not handed over and its movie is deleted")
    func processingFailureDiscardsMovie() async throws {
        let movieURL = TestDirectory.current.appendingPathComponent(UUID().uuidString + ".mov")
        try Data([0]).write(to: movieURL)
        let service = RecordingCameraService()
        service.deliveredPhoto = CapturedPhoto(
            imageData: Data([1, 2, 3]),
            encoding: .heif,
            livePhotoMovieURL: movieURL
        )
        var photos: [CameraCapture] = []
        let model = makeCaptureModel(service: service) { photos.append($0) }
        await model.start()
        await model.capture()
        #expect(photos.isEmpty)
        #expect(model.notices.captureError == .cannotCrop("The photo cannot be decoded"))
        #expect(FileManager.default.fileExists(atPath: movieURL.path) == false)
    }

    @Test("A capture error is cleared when a setting changes")
    func settingClearsCaptureError() async {
        let service = RecordingCameraService()
        service.captureError = .captureFailed("Test")
        let model = makeCaptureModel(service: service)
        await model.start()
        await model.capture()
        #expect(model.notice.map(CameraNoticeText(.system).message) == "Photo could not be taken")
        model.settings.select(aspectRatio: .square)
        #expect(model.notices.captureError == nil)
        #expect(model.notice.map(CameraNoticeText(.system).message) == nil)
    }

    @Test("A capture error is cleared when the next capture starts")
    func captureClearsCaptureError() async {
        let service = RecordingCameraService()
        service.captureError = .captureFailed("Test")
        let model = makeCaptureModel(service: service)
        await model.start()
        await model.capture()
        service.captureError = nil
        service.holdsCalls = true
        let nextCapture = Task { await model.capture() }
        await settle { service.heldCallCount == 1 }
        #expect(model.notices.captureError == nil)
        service.releaseHeldCalls()
        await nextCapture.value
    }

    // MARK: - Authorization and session

    @Test(
        "A camera the user denied and one a policy restricts are told apart, and neither is started",
        arguments: [(CameraAuthorization.denied, CameraFailure.accessDenied), (.restricted, .accessRestricted)]
    )
    func refusedAccess(authorization: CameraAuthorization, failure: CameraFailure) async {
        let service = RecordingCameraService()
        service.authorization = authorization
        let model = makeCaptureModel(service: service)
        await model.start()
        #expect(model.session.failure == failure)
        #expect(service.calls.isEmpty)
    }

    @Test("A device with no camera is not asked for access, and says that the camera is unavailable")
    func noCamera() async {
        let service = RecordingCameraService()
        service.cameraPositions = []
        service.authorization = .denied
        let model = makeCaptureModel(service: service)
        await model.start()
        #expect(service.authorizationRequestCount == 0)
        #expect(model.session.failure == .unavailable(.noCamera))
        #expect(service.calls.isEmpty)
    }

    @Test(
        "Only a camera the user denied is lifted in Settings",
        arguments: [
            (CameraFailure.accessDenied, true),
            (.accessRestricted, false),
            (.unavailable(.noCamera), false),
            (.stopped, false)
        ]
    )
    func liftedInSettings(failure: CameraFailure, isLiftedInSettings: Bool) {
        #expect(failure.isLiftedInSettings == isLiftedInSettings)
    }

    @Test("An interruption fails captures until it ends")
    func interruption() async throws {
        let service = RecordingCameraService()
        let model = makeCaptureModel(service: service)
        await model.start()
        await service.simulate(.interrupted(.cameraInUseByAnotherClient))
        #expect(model.session.interruption == .cameraInUseByAnotherClient)
        await model.capture()
        #expect(model.notices.captureError == .interrupted(.cameraInUseByAnotherClient))
        #expect(service.captureRequests.isEmpty)
        await service.simulate(.interruptionEnded)
        #expect(model.session.interruption == nil)
        await model.capture()
        #expect(model.notices.captureError == nil)
        #expect(service.captureRequests.count == 1)
    }

    @Test("A runtime error that a new start does not recover from is shown as a failure")
    func runtimeError() async {
        let service = RecordingCameraService()
        let model = makeCaptureModel(service: service)
        await model.start()
        let error = CameraRuntimeError(message: "Media services were lost", isRecoverable: false)
        await service.simulate(.runtimeError(error))
        #expect(model.session.failure == .stopped)
    }

    @Test("A capture error from the camera is kept as typed")
    func captureError() async {
        let service = RecordingCameraService()
        service.captureError = .captureFailed("Pipeline stalled")
        var photos: [CameraCapture] = []
        let model = makeCaptureModel(service: service) { photos.append($0) }
        await model.start()
        await model.capture()
        #expect(model.notices.captureError == .captureFailed("Pipeline stalled"))
        #expect(photos.isEmpty)
    }

    @Test("Capturing before the camera started fails as not running")
    func notStarted() async {
        let service = RecordingCameraService()
        let model = makeCaptureModel(service: service)
        await model.capture()
        #expect(model.notices.captureError == .notRunning)
    }

    // MARK: - Flash

    @Test(
        "Flash follows the setting on the back camera and on the front one, which offers the flash of the screen",
        arguments: CameraFlowFlashMode.allCases
    )
    func flash(mode: CameraFlowFlashMode) async {
        let service = RecordingCameraService()
        var state = CameraFlowInitialState()
        state.flashMode.value = mode
        let model = makeCaptureModel(service: service, initialState: state)
        await model.start()
        await model.capture()
        await model.flipCamera()
        await model.capture()
        #expect(service.captureRequests.map(\.flashMode) == [mode, mode])
    }

    // MARK: - Live Photo

    @Test("A Live Photo hands over the still and its movie file together")
    func livePhoto() async throws {
        let service = RecordingCameraService()
        var photos: [CameraCapture] = []
        var state = CameraFlowInitialState()
        state.isLivePhotoEnabled.value = true
        let model = makeCaptureModel(service: service, initialState: state) { photos.append($0) }
        await model.start()
        #expect(model.settings.isLivePhotoAvailable)
        await model.capture()
        let photo = try #require(photos.first)
        let movieURL = try #require(photo.livePhotoMovieURL)
        #expect(FileManager.default.fileExists(atPath: movieURL.path))
        #expect(movieURL.deletingLastPathComponent() == photo.fileURL.deletingLastPathComponent())
        #expect(movieURL.deletingPathExtension().lastPathComponent == photo.id.uuidString)
        #expect(service.captureRequests.first?.isLivePhotoEnabled == true)
        try CaptureTestSupport.discardFiles(of: photo)
    }

    @Test(
        "Live Photo on has no effect on a camera without it: the photo is a still one",
        arguments: [CameraFlowSetting(true), .fixed(true)]
    )
    func livePhotoUnsupported(setting: CameraFlowSetting<Bool>) async throws {
        let service = RecordingCameraService(backPhotoCapabilities: CaptureTestSupport.narrowCapabilities)
        var photos: [CameraCapture] = []
        var state = CameraFlowInitialState()
        state.isLivePhotoEnabled = setting
        let model = makeCaptureModel(service: service, initialState: state) { photos.append($0) }
        await model.start()
        #expect(model.settings.isLivePhotoEnabled)
        #expect(model.settings.isLivePhotoAvailable == false)
        #expect(model.settings.isLivePhotoInEffect == false)
        await model.capture()
        #expect(model.notices.captureError == nil)
        #expect(service.captureRequests.map(\.isLivePhotoEnabled) == [false])
        let photo = try #require(photos.first)
        #expect(photo.livePhotoMovieURL == nil)
        try CaptureTestSupport.discardFiles(of: photo)
    }

    @Test(
        "Live Photo is taken in 4:3 only: in another ratio it stays chosen, cannot be switched and takes a still photo",
        arguments: [CameraFlowAspectRatio.sixteenByNine, .square]
    )
    func livePhotoInAnotherRatio(aspectRatio: CameraFlowAspectRatio) async throws {
        let service = RecordingCameraService()
        var photos: [CameraCapture] = []
        var state = CameraFlowInitialState()
        state.isLivePhotoEnabled.value = true
        let model = makeCaptureModel(service: service, initialState: state) { photos.append($0) }
        await model.start()
        #expect(model.settings.isLivePhotoInEffect)
        model.settings.select(aspectRatio: aspectRatio)
        #expect(model.settings.isLivePhotoEnabled)
        #expect(model.settings.isLivePhotoAvailable)
        #expect(model.settings.isLivePhotoSelectable == false)
        #expect(model.settings.isLivePhotoInEffect == false)
        await model.capture()
        #expect(model.notices.captureError == nil)
        #expect(service.captureRequests.map(\.isLivePhotoEnabled) == [false])
        #expect(photos.first?.livePhotoMovieURL == nil)
        model.settings.select(aspectRatio: .fourByThree)
        #expect(model.settings.isLivePhotoSelectable)
        #expect(model.settings.isLivePhotoInEffect)
        try photos.forEach(CaptureTestSupport.discardFiles)
    }

    // MARK: - Exposure

    @Test(
        "Exposure bias is clamped to the screen range and the device range, then sent",
        arguments: [(0.7, 0.7), (-3.0, -1.0), (1.8, 1.5), (5.0, 1.5)]
    )
    func exposure(requested: Double, applied: Double) async {
        let service = RecordingCameraService(backPhotoCapabilities: CaptureTestSupport.narrowCapabilities)
        let model = makeCaptureModel(service: service)
        await model.start()
        #expect(model.settings.availableExposureBiasRange == -1...1.5)
        model.settings.setExposureBias(requested)
        #expect(model.settings.exposureBias == applied)
        #expect(service.calls.last == .exposureBias(applied))
    }

    @Test("Exposure set before the camera starts is only state, and is applied at start")
    func exposureBeforeStart() async {
        let service = RecordingCameraService()
        let model = makeCaptureModel(service: service)
        model.settings.setExposureBias(1.3)
        #expect(service.calls.isEmpty)
        await model.start()
        #expect(service.calls == [.start(.back), .exposureBias(1.3)])
    }
}
