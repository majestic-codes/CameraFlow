//
//  SimulatedCameraFeaturesTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("The costly photo features a simulated camera turns on", .temporaryDirectory, .timeLimit(.minutes(1)))
struct SimulatedCameraFeaturesTests {

    @Test(
        "A camera started for a flow has Live Photo and RAW only where the flow can use them, alone and as a pair",
        arguments: [
            PhotoCaptureFeatures(livePhoto: false, raw: false),
            PhotoCaptureFeatures(livePhoto: true, raw: false),
            PhotoCaptureFeatures(livePhoto: false, raw: true),
            PhotoCaptureFeatures.all
        ]
    )
    func startedCamera(features: PhotoCaptureFeatures) async throws {
        let service = SimulatedCameraService(scene: .black, features: features)
        _ = try await service.start(position: .back)
        let back = try #require(service.photoCapabilities)
        #expect(back.isLivePhotoSupported == features.livePhoto)
        #expect(back.formats.contains(.raw) == features.raw)
        _ = try await service.startDualCamera(main: .back)
        let dual = try #require(service.photoCapabilities)
        let wholeDual = SimulatedCameraService.iPhoneDualPhotoCapabilities
        #expect(dual == wholeDual.narrowed(to: features))
    }
}
