//
//  UnnamedPhotoSizeTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("A camera without 12 MP", .temporaryDirectory, .timeLimit(.minutes(1)))
struct UnnamedPhotoSizeTests {
    /// The one photo size of an older camera.
    struct UnnamedSize: Sendable {
        let width: Int32
        let height: Int32
        let megapixels: Int
    }

    /// A camera with one photo size, as `PhotoCaptureResolution.offered(among:)` reports it.
    private static func capabilities(width: Int32, height: Int32) -> PhotoCaptureCapabilities {
        PhotoCaptureCapabilities(
            flashModes: [.off],
            isLivePhotoSupported: false,
            exposureBiasRange: -8...8,
            formats: [.heif],
            encodesHEVC: true,
            resolution: PhotoCaptureResolution.offered(among: [(width, height)]),
            lockableAdjustments: .focusAndExposure
        )
    }

    @Test(
        "It takes the photo at its own size, saving or not",
        arguments: [
            UnnamedSize(width: 3264, height: 2448, megapixels: 8),
            UnnamedSize(width: 3088, height: 2316, megapixels: 7)
        ],
        [true, false]
    )
    func capture(size: UnnamedSize, isSavingOn: Bool) async throws {
        let capabilities = Self.capabilities(width: size.width, height: size.height)
        let service = RecordingCameraService(backPhotoCapabilities: capabilities)
        var photos: [CameraCapture] = []
        let model = makeCaptureModel(
            service: service,
            librarySaving: CaptureTestSupport.makeLibrarySaving(isOn: isSavingOn)
        ) { photos.append($0) }
        await model.start()
        let settings = model.settings
        #expect(settings.deliversPhotos(within: settings.output))
        #expect(settings.effectivePhotoFrame?.isPreferred == false)
        #expect(settings.effectivePhotoFrame?.megapixels == size.megapixels)
        #expect(settings.availablePhotoFormats == [.heif])
        await model.capture()
        #expect(model.notices.captureError == nil)
        let request = try #require(service.captureRequests.first)
        #expect(request.resolution.width == size.width)
        #expect(request.resolution.height == size.height)
        #expect(photos.count == 1)
        try photos.forEach(CaptureTestSupport.discardFiles)
    }

    @Test("A size limit below the size leaves it for the output to scale down")
    func sizeLimit() async {
        let service = RecordingCameraService(backPhotoCapabilities: Self.capabilities(width: 3264, height: 2448))
        var output = CameraFlowOutput()
        output.size = .longSide(maximum: 2048)
        let model = makeCaptureModel(service: service, output: output)
        await model.start()
        #expect(model.settings.effectivePhotoFrame?.width == 3264)
    }
}
