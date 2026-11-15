//
//  RapidShootingTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

/// Quick taps of the shutter, as the stock camera takes them: each tap takes a photo while the photos before it are
/// still on their way, and the photos reach the receiver one at a time, in the order they were shot. Each tap is made
/// in another aspect ratio, whose size tells its photo apart.
@MainActor
@Suite("Rapid shooting", .temporaryDirectory, .timeLimit(.minutes(1)))
struct RapidShootingTests {
    let service = RecordingCameraService()

    /// A camera that delivers the device fixture and holds every capture until the test lets it go.
    private func makeModel(onCapture: @escaping (CameraCapture) -> Void) async throws -> PhotoCameraModel {
        let fixture = try DevicePhotoFixture.make()
        service.deliveredPhoto = CapturedPhoto(imageData: fixture, encoding: .heif, livePhotoMovieURL: nil)
        let model = makeCaptureModel(service: service, onCapture: onCapture)
        await model.start()
        service.holdsCalls = true
        return model
    }

    /// Taps the shutter once in each ratio, and returns once the camera holds every shot.
    private func tap(_ model: PhotoCameraModel, in ratios: [CameraFlowAspectRatio]) async -> [Task<Void, Never>] {
        var taps: [Task<Void, Never>] = []
        for ratio in ratios {
            model.settings.select(aspectRatio: ratio)
            taps.append(Task { await model.capture() })
            let count = taps.count
            await settle { service.heldCallCount == count }
        }
        return taps
    }

    /// The upright size of the device fixture's photo in a ratio.
    private static func size(in ratio: CameraFlowAspectRatio) -> CGSize {
        switch ratio {
        case .fourByThree: CGSize(width: 192, height: 256)
        case .square: CGSize(width: 192, height: 192)
        case .sixteenByNine: CGSize(width: 144, height: 256)
        }
    }

    private static func sizes(of captures: [CameraCapture]) throws -> [CGSize] {
        try captures.map { try $0.uprightPixelSize() }
    }

    @Test("Taps before the first photo arrives each take one, and the photos arrive in the order they were shot")
    func burst() async throws {
        var captures: [CameraCapture] = []
        let model = try await makeModel { captures.append($0) }
        let ratios: [CameraFlowAspectRatio] = [.fourByThree, .square, .sixteenByNine]
        let taps = await tap(model, in: ratios)
        #expect(service.captureRequests.count == 3)
        #expect(model.shutter.captureCount == 3)
        #expect(model.shutter.photosInFlight == 3)
        #expect(captures.isEmpty)
        service.releaseHeldCalls()
        for tap in taps {
            await tap.value
        }
        #expect(try Self.sizes(of: captures) == ratios.map(Self.size))
        #expect(model.shutter.isCapturing == false)
        #expect(model.notice == nil)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    /// The second photo is a 4:3 one, which the pipeline only copies, and the first a square one, which it crops and
    /// encodes again: handed over as they come, the second would arrive first.
    @Test("A photo the camera delivers first waits for the photo shot before it")
    func deliveredOutOfOrder() async throws {
        var captures: [CameraCapture] = []
        let model = try await makeModel { captures.append($0) }
        let taps = await tap(model, in: [.square, .fourByThree])
        service.releaseHeldCapture(at: 1)
        await settle { service.endedCaptureCount == 1 }
        await settleQueuedWork()
        #expect(captures.isEmpty)
        #expect(model.shutter.photosInFlight == 2)
        service.releaseHeldCapture(at: 0)
        for tap in taps {
            await tap.value
        }
        #expect(try Self.sizes(of: captures) == [Self.size(in: .square), Self.size(in: .fourByThree)])
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    @Test("A photo that fails between two others holds up neither, and says so in its turn")
    func failureInTheMiddle() async throws {
        var captures: [CameraCapture] = []
        let model = try await makeModel { captures.append($0) }
        let taps = await tap(model, in: [.fourByThree, .square, .sixteenByNine])
        service.captureError = .captureFailed("The sensor gave nothing")
        service.releaseHeldCapture(at: 1)
        await settle { service.endedCaptureCount == 1 }
        service.captureError = nil
        service.releaseHeldCapture(at: 1)
        await settle { service.endedCaptureCount == 2 }
        await settleQueuedWork()
        #expect(captures.isEmpty)
        #expect(model.notices.captureError == nil)
        service.releaseHeldCapture(at: 0)
        for tap in taps {
            await tap.value
        }
        #expect(try Self.sizes(of: captures) == [Self.size(in: .fourByThree), Self.size(in: .sixteenByNine)])
        #expect(model.notices.captureError == .captureFailed("The sensor gave nothing"))
        #expect(model.shutter.isCapturing == false)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }
}
