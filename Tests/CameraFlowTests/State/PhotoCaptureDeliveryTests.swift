//
//  PhotoCaptureDeliveryTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import CoreLocation
import Foundation
import ImageIO
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Photo capture delivery", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoCaptureDeliveryTests {
    // MARK: - Untouched original

    @Test("The camera's own 4:3 file reaches the receiver byte for byte through the model")
    func untouchedThroughModel() async throws {
        let service = RecordingCameraService()
        let original = try DevicePhotoFixture.make()
        service.deliveredPhoto = CapturedPhoto(
            imageData: original,
            encoding: .heif,
            livePhotoMovieURL: nil
        )
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service) { captures.append($0) }
        await model.start()
        await model.capture()
        let capture = try #require(captures.first)
        #expect(try Data(contentsOf: capture.fileURL) == original)
        try CaptureTestSupport.discardFiles(of: capture)
    }

    // MARK: - The capture

    @Test("Every capture of a session gets files of its own")
    func manyCaptures() async throws {
        let service = RecordingCameraService()
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service) { captures.append($0) }
        await model.start()
        for _ in 0..<3 {
            await model.capture()
        }
        #expect(captures.count == 3)
        #expect(Set(captures.map(\.fileURL)).count == 3)
        #expect(Set(captures.map(\.id)).count == 3)
        #expect(Set(captures.map { $0.fileURL.deletingLastPathComponent() }) == [model.delivery.files.directory])
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    // MARK: - Ownership

    @Test("A capture that finishes after the screen closed is deleted, not handed over")
    func closedBeforeDelivery() async throws {
        let service = RecordingCameraService()
        var captures: [CameraCapture] = []
        var state = CameraFlowInitialState()
        state.isLivePhotoEnabled.value = true
        let model = makeCaptureModel(service: service, initialState: state) { captures.append($0) }
        await model.start()
        service.holdsCalls = true
        let capturing = Task { await model.capture() }
        await settle { service.heldCallCount == 1 }
        model.close()
        service.releaseHeldCalls()
        await capturing.value
        #expect(captures.isEmpty)
        #expect(FileManager.default.fileExists(atPath: model.delivery.files.directory.path) == false)
    }

    @Test("Closing keeps the files already handed over and removes an empty directory")
    func closeKeepsDelivered() async throws {
        let service = RecordingCameraService()
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service) { captures.append($0) }
        await model.start()
        await model.capture()
        let capture = try #require(captures.first)
        model.close()
        #expect(FileManager.default.fileExists(atPath: capture.fileURL.path))
        try CaptureTestSupport.discardFiles(of: capture)
        model.close()
        #expect(FileManager.default.fileExists(atPath: model.delivery.files.directory.path) == false)
    }

    @Test("A receiver that moves the files away leaves no session directory behind")
    func receiverMovesFiles() async throws {
        let service = RecordingCameraService()
        let keptDirectory = TestDirectory.current.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: keptDirectory, withIntermediateDirectories: true)
        var kept: [URL] = []
        let model = makeCaptureModel(service: service) { capture in
            let destination = keptDirectory.appendingPathComponent(capture.fileURL.lastPathComponent)
            do {
                try FileManager.default.moveItem(at: capture.fileURL, to: destination)
                kept.append(destination)
            } catch {
                Issue.record("Cannot move the capture: \(error)")
            }
        }
        await model.start()
        await model.capture()
        await model.capture()
        #expect(kept.count == 2)
        #expect(FileManager.default.fileExists(atPath: model.delivery.files.directory.path) == false)
        try FileManager.default.removeItem(at: keptDirectory)
    }

    // MARK: - Location

    @Test("The location the provider returns at the shutter is written into the file")
    func location() async throws {
        let service = RecordingCameraService()
        var captures: [CameraCapture] = []
        var calls = 0
        let location = LocationFixture.location(latitude: -33.86, longitude: 151.21)
        let state = CameraFlowInitialState()
        let onCapture: (CameraCapture) -> Void = { captures.append($0) }
        let model = makeCaptureModel(service: service, initialState: state, onCapture: onCapture) {
            calls += 1
            return location
        }
        await model.start()
        #expect(calls == 0)
        await model.capture()
        #expect(calls == 1)
        #expect(service.captureRequests.first?.location == location)
        let capture = try #require(captures.first)
        let properties = try ImageFile.properties(of: capture.fileURL)
        let gps = try #require(properties[kCGImagePropertyGPSDictionary] as? [CFString: Any])
        #expect(gps[kCGImagePropertyGPSLatitudeRef] as? String == "S")
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("Without a location the file has no GPS dictionary")
    func noLocation() async throws {
        let service = RecordingCameraService()
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service, onCapture: { captures.append($0) }, locationProvider: { nil })
        await model.start()
        await model.capture()
        let capture = try #require(captures.first)
        let properties = try ImageFile.properties(of: capture.fileURL)
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        #expect(service.captureRequests.first?.location == nil)
        try CaptureTestSupport.discardFiles(of: capture)
    }
}
