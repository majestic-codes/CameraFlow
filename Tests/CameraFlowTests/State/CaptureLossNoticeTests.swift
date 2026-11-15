//
//  CaptureLossNoticeTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("A photo taken without a part that failed", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CaptureLossNoticeTests {
    let service = RecordingCameraService()

    @Test(
        "The photo is handed over and the notice says what it lacks, until the next capture",
        arguments: [
            (CapturedPhotoLoss.livePhotoMovie, "Photo taken without Live Photo"),
            (.circleCameraFrame, "Photo taken without Dual Capture")
        ]
    )
    func handedOverWithNotice(loss: CapturedPhotoLoss, notice: String) async throws {
        var lacking = CapturedPhoto(imageData: try DevicePhotoFixture.make(), encoding: .heif, livePhotoMovieURL: nil)
        lacking.losses = [loss]
        service.deliveredPhoto = lacking
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service) { captures.append($0) }
        await model.start()
        await model.capture()
        #expect(captures.count == 1)
        #expect(model.notices.captureError == nil)
        #expect(model.notices.captureLoss == loss)
        #expect(model.notice == .captureLoss(loss))
        #expect(model.notice.map(CameraNoticeText(.system).message) == notice)
        service.deliveredPhoto = CapturedPhoto(
            imageData: try DevicePhotoFixture.make(),
            encoding: .heif,
            livePhotoMovieURL: nil
        )
        await model.capture()
        #expect(captures.count == 2)
        #expect(model.notices.captureLoss == nil)
        #expect(model.notice.map(CameraNoticeText(.system).message) == nil)
        for capture in captures {
            try CaptureTestSupport.discardFiles(of: capture)
        }
    }

    @Test("What a photo was taken without comes after a failed capture and before the circle, and goes with them")
    func order() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        model.notices.showDualCameraNotice(.unavailable)
        model.notices.showCaptureLossNotice(.livePhotoMovie)
        #expect(model.notice == .captureLoss(.livePhotoMovie))
        model.notices.captureFailed(with: .notRunning)
        #expect(model.notice == .captureFailed(.notRunning))
        model.clearNotices()
        #expect(model.notices.captureLoss == nil)
        #expect(model.notice == nil)
    }
}
