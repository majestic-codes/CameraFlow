//
//  PhotoCaptureFormatTests.swift
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
@Suite("Photo format, size and aspect ratio", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoCaptureFormatTests {
    // MARK: - Format and size

    @Test(
        "The format and 12 MP reach the camera in a flow that saves, and only RAW stays uncropped",
        arguments: [(CameraFlowPhotoFormat.heif, true), (CameraFlowPhotoFormat.raw, false)]
    )
    func format(format: CameraFlowPhotoFormat, isCropped: Bool) async throws {
        let service = RecordingCameraService()
        var photos: [CameraCapture] = []
        var state = CameraFlowInitialState()
        state.photoFormat.value = format
        state.aspectRatio.value = .square
        let librarySaving = CaptureTestSupport.makeLibrarySaving()
        let model = makeCaptureModel(service: service, initialState: state, librarySaving: librarySaving) {
            photos.append($0)
        }
        await model.start()
        await model.capture()
        let request = try #require(service.captureRequests.first)
        #expect(request.format == format)
        #expect(request.resolution.isPreferred)
        let photo = try #require(photos.first)
        #expect(try CaptureTestSupport.isSquare(photo) == isCropped)
        #expect((photo.framedRegion != nil) == !isCropped)
        try CaptureTestSupport.discardFiles(of: photo)
    }

    @Test("HEIF falls back to JPEG on a camera without HEVC")
    func jpegFallback() async throws {
        let service = RecordingCameraService(backPhotoCapabilities: CaptureTestSupport.narrowCapabilities)
        var photos: [CameraCapture] = []
        let model = makeCaptureModel(service: service) { photos.append($0) }
        await model.start()
        await model.capture()
        let photo = try #require(photos.first)
        #expect(photo.contentType == .jpeg)
        #expect(photo.fileURL.pathExtension == "jpeg")
        try CaptureTestSupport.discardFiles(of: photo)
    }

    @Test(
        "Only the formats the camera has are offered, and its photos fit the output",
        arguments: [CameraPosition.back, .front]
    )
    func offered(position: CameraPosition) async {
        let service = RecordingCameraService()
        let model = makeCaptureModel(service: service, librarySaving: CaptureTestSupport.makeLibrarySaving())
        await model.start()
        if position == .front {
            await model.flipCamera()
        }
        let isBack = position == .back
        #expect(model.settings.availablePhotoFormats == (isBack ? [.heif, .raw] : [.heif]))
        #expect(model.settings.deliversPhotos(within: model.settings.output))
    }

    @Test("The front camera shoots at 12 MP, which it has")
    func effectiveResolution() async {
        let service = RecordingCameraService()
        let model = makeCaptureModel(service: service)
        await model.start()
        await model.flipCamera()
        #expect(model.settings.effectivePhotoFrame?.isPreferred == true)
        await model.capture()
        #expect(service.captureRequests.map(\.resolution.isPreferred) == [true])
    }

    @Test("RAW on a camera without it falls back to HEIF, as the panel offers no RAW to pick")
    func rawUnsupported() async throws {
        let service = RecordingCameraService()
        var photos: [CameraCapture] = []
        var state = CameraFlowInitialState()
        state.photoFormat.value = .raw
        let model = makeCaptureModel(service: service, initialState: state) { photos.append($0) }
        await model.start()
        await model.flipCamera()
        #expect(model.settings.photoFormat == .raw)
        #expect(model.settings.effectivePhotoFormat == .heif)
        #expect(model.settings.offeredPhotoFormats == [.heif])
        await model.capture()
        #expect(model.notices.captureError == nil)
        #expect(service.captureRequests.map(\.format) == [.heif])
        try photos.forEach(CaptureTestSupport.discardFiles)
    }

    // MARK: - Aspect ratio

    @Test(
        "The handed-over photo has the chosen ratio",
        arguments: [(CameraFlowAspectRatio.fourByThree, 3.0 / 4.0), (.sixteenByNine, 9.0 / 16.0), (.square, 1.0)]
    )
    func aspect(aspectRatio: CameraFlowAspectRatio, widthPerHeight: Double) async throws {
        let service = RecordingCameraService()
        var photos: [CameraCapture] = []
        var state = CameraFlowInitialState()
        state.aspectRatio.value = aspectRatio
        let model = makeCaptureModel(service: service, initialState: state) { photos.append($0) }
        await model.start()
        await model.capture()
        let photo = try #require(photos.first)
        let size = try photo.uprightPixelSize()
        expectClose(size.width / size.height, widthPerHeight, tolerance: 0.01)
        try CaptureTestSupport.discardFiles(of: photo)
    }
}
