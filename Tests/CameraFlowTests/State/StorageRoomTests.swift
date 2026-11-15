//
//  StorageRoomTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// The room left on the device before a shot: the stock camera refuses the shot of a full device before its
/// shutter and says why, instead of taking a photo it cannot keep.
@MainActor
@Suite("The room for a photo", .temporaryDirectory, .timeLimit(.minutes(1)))
struct StorageRoomTests {
    let service = RecordingCameraService()

    @Test("A device with too little room refuses the shot before the shutter and says why")
    func refusesShot() async {
        let storage = FakeStorageSpace(room: .bytes(10_000_000))
        let model = makeCaptureModel(service: service, storage: storage)
        await model.start()
        await model.capture()
        #expect(service.captureRequests.isEmpty)
        #expect(model.shutter.captureCount == 0)
        #expect(model.shutter.isCapturing == false)
        #expect(model.notice == .captureFailed(.notEnoughStorage))
        #expect(model.notice.map(CameraNoticeText(.system).message) == "Not enough storage")
    }

    @Test(
        "A device with the room takes the shot",
        arguments: [FakeStorageSpace.Room.bytes(ShutterModel.minimumFreeBytes), .bytes(FakeStorageSpace.plenty)]
    )
    func takesShot(room: FakeStorageSpace.Room) async throws {
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service, storage: FakeStorageSpace(room: room)) { captures.append($0) }
        await model.start()
        await model.capture()
        #expect(service.captureRequests.count == 1)
        #expect(model.notice == nil)
        #expect(captures.count == 1)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    @Test("A volume that does not say how much room it has lets the shot be taken")
    func unknownRoom() async throws {
        var captures: [CameraCapture] = []
        let storage = FakeStorageSpace(room: .unknown)
        let model = makeCaptureModel(service: service, storage: storage) { captures.append($0) }
        await model.start()
        await model.capture()
        #expect(storage.readCount == 1)
        #expect(captures.count == 1)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    @Test("A second press while the room of the first is read takes no second photo")
    func pressWhileReading() async throws {
        let gate = CallGate()
        let storage = FakeStorageSpace(gate: gate)
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service, storage: storage) { captures.append($0) }
        await model.start()
        let first = Task { await model.capture() }
        await gate.arrival()
        await model.capture()
        #expect(storage.readCount == 1)
        await gate.open()
        await first.value
        #expect(service.captureRequests.count == 1)
        #expect(captures.count == 1)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }
}
