//
//  ForeignCameraErrorTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("A camera that fails with an error that is not its own", .temporaryDirectory, .timeLimit(.minutes(1)))
struct ForeignCameraErrorTests {
    private let service = ForeignErrorCameraService()
    private let error = ForeignCameraError(description: "The media server died")

    private func makeModel(
        isDualCameraOffered: Bool = false,
        onCapture: @escaping (CameraCapture) -> Void = { _ in }
    ) -> PhotoCameraModel {
        var state = CameraFlowInitialState()
        if !isDualCameraOffered {
            state.isDualCameraEnabled = .fixed(false)
        }
        return PhotoCameraModel(
            service: service,
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            initialState: state,
            clock: ManualClock(),
            files: CaptureTestSupport.makeFileStore(),
            onCapture: onCapture
        )
    }

    @Test("A start that fails so shows a camera that cannot be used, with the error in its own words, to retry from")
    func start() async {
        service.startError = error
        let model = makeModel()
        await model.start()
        #expect(model.session.failure == .unavailable(.cannotUseCamera("The media server died")))
        #expect(model.session.failure?.isRetryable == true)
        let failure = CameraFailure.unavailable(.cannotUseCamera("The media server died"))
        #expect(CameraNoticeText(.system).message(for: failure) == "Camera unavailable")
        service.startError = nil
        await model.retry()
        #expect(model.session.failure == nil)
        #expect(model.session.capabilities != nil)
    }

    @Test("A pair that fails so leaves the single camera running and says that the front camera is unavailable")
    func dualStart() async {
        let model = makeModel(isDualCameraOffered: true)
        await model.start()
        service.dualStartError = error
        await model.toggleDualCamera()
        #expect(model.session.isDualCameraOn == false)
        #expect(model.session.failure == nil)
        #expect(model.session.capabilities?.position == .back)
        #expect(model.notices.dualCameraNotice == .unavailable)
        #expect(model.notice.map(CameraNoticeText(.system).message) == "Front camera unavailable")
    }

    @Test("A capture that fails so hands over nothing and says that the photo could not be taken")
    func capture() async throws {
        var captures: [CameraCapture] = []
        let model = makeModel { captures.append($0) }
        await model.start()
        service.captureError = error
        await model.capture()
        #expect(captures.isEmpty)
        #expect(model.notices.captureError == .captureFailed("The media server died"))
        #expect(model.notice.map(CameraNoticeText(.system).message) == "Photo could not be taken")
        #expect(model.shutter.isCapturing == false)
        service.captureError = nil
        await model.capture()
        #expect(captures.count == 1)
        #expect(model.notices.captureError == nil)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }
}
