//
//  PhotoSetModelTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("Photo set", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoSetModelTests {
    let files = CaptureTestSupport.makeFileStore()

    private func makeSet(
        limit: CameraFlowPhotoLimit = .unlimited,
        onHandOver: @escaping ([CameraFlowPhoto]) -> Void = { _ in Issue.record("Nothing is handed over") }
    ) -> PhotoSetModel {
        PhotoSetModel(limit: limit, fileStore: files, renderer: RecordingMarkupRenderer(), onHandOver: onHandOver)
    }

    @Test("A new set is empty and takes photos")
    func startsEmpty() {
        let photoSet = makeSet()
        #expect(photoSet.isEmpty)
        #expect(photoSet.isFull == false)
        #expect(photoSet.isImporting == false)
        #expect(photoSet.hasCameraPhotos == false)
        #expect(photoSet.hasEnded == false)
        #expect(photoSet.notice == nil)
    }

    @Test("Captures stay in the order they were added, as photos of the camera")
    func addsCaptures() throws {
        let photoSet = makeSet()
        let captures = try [true, false].map { try FlowTestSupport.makeCapture(in: files, withMovie: $0) }
        captures.forEach(photoSet.add)
        #expect(photoSet.photos.map(\.id) == captures.map(\.id))
        #expect(photoSet.photos.map(\.source) == [.camera, .camera])
        #expect(photoSet.photos.map(\.livePhotoMovieURL) == captures.map(\.livePhotoMovieURL))
        #expect(photoSet.hasCameraPhotos)
        photoSet.discard()
    }

    @Test("The hand-over passes every photo in order, once, and leaves their files")
    func handOverOnce() async throws {
        var handedOver: [[CameraFlowPhoto]] = []
        let photoSet = makeSet { handedOver.append($0) }
        let captures = try (0..<3).map { _ in try FlowTestSupport.makeCapture(in: files) }
        captures.forEach(photoSet.add)
        await photoSet.handOver()
        await photoSet.handOver()
        photoSet.discard()
        try #require(handedOver.count == 1)
        #expect(handedOver[0].map(\.id) == captures.map(\.id))
        #expect(photoSet.isEmpty)
        #expect(photoSet.hasEnded)
        #expect(captures.allSatisfy { FlowTestSupport.fileExists($0.fileURL) })
        try FlowTestSupport.discardFiles(of: handedOver[0])
    }

    @Test("Discarding deletes the photos and movies of the set and their directory")
    func discardDeletes() async throws {
        let photoSet = makeSet()
        try photoSet.add(FlowTestSupport.makeCapture(in: files, withMovie: true))
        try photoSet.add(FlowTestSupport.makeCapture(in: files))
        let photos = photoSet.photos
        photoSet.discard()
        await photoSet.handOver()
        expectDeleted(photos)
        #expect(FlowTestSupport.fileExists(files.directory) == false)
        #expect(photoSet.isEmpty)
        #expect(photoSet.hasEnded)
    }

    @Test("A capture arriving after the set ended is deleted", arguments: [true, false])
    func lateCaptureDeleted(isHandedOver: Bool) async throws {
        var handedOver: [CameraFlowPhoto] = []
        let photoSet = makeSet { handedOver += $0 }
        if isHandedOver {
            await photoSet.handOver()
        } else {
            photoSet.discard()
        }
        let late = try FlowTestSupport.makeCapture(in: files, withMovie: true)
        photoSet.add(late)
        expectDeleted([FlowPhoto(capture: late)])
        #expect(FlowTestSupport.fileExists(files.directory) == false)
        #expect(photoSet.isEmpty)
        #expect(handedOver.isEmpty)
    }

    @Test("Removing a photo deletes its files and keeps the others in order")
    func remove() async throws {
        var handedOver: [CameraFlowPhoto] = []
        let photoSet = makeSet { handedOver += $0 }
        for hasMovie in [false, true, false] {
            try photoSet.add(FlowTestSupport.makeCapture(in: files, withMovie: hasMovie))
        }
        let photos = photoSet.photos
        try #require(photos.count == 3)
        photoSet.remove(photos[1])
        photoSet.remove(photos[1])
        expectDeleted([photos[1]])
        #expect(photoSet.photos.map(\.id) == [photos[0].id, photos[2].id])
        await photoSet.handOver()
        #expect(handedOver.map(\.id) == [photos[0].id, photos[2].id])
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    // MARK: - Limit

    @Test("A set without a limit never fills")
    func unlimited() throws {
        let photoSet = makeSet()
        try photoSet.add(FlowTestSupport.makeCapture(in: files))
        #expect(photoSet.remainingCapacity == nil)
        #expect(photoSet.isFull == false)
        #expect(photoSet.captureRefusal(photosInFlight: 0) == nil)
        photoSet.discard()
    }

    @Test("The limit counts down, refuses the shutter when reached and deletes a capture beyond it")
    func limit() async throws {
        var handedOver: [CameraFlowPhoto] = []
        let photoSet = makeSet(limit: .maximum(2)) { handedOver += $0 }
        #expect(photoSet.remainingCapacity == 2)
        try photoSet.add(FlowTestSupport.makeCapture(in: files))
        #expect(photoSet.remainingCapacity == 1)
        #expect(photoSet.captureRefusal(photosInFlight: 0) == nil)
        try photoSet.add(FlowTestSupport.makeCapture(in: files))
        #expect(photoSet.remainingCapacity == 0)
        #expect(photoSet.isFull)
        #expect(photoSet.captureRefusal(photosInFlight: 0) == .captureLimitReached(2))
        let extra = try FlowTestSupport.makeCapture(in: files)
        photoSet.add(extra)
        expectDeleted([FlowPhoto(capture: extra)])
        await photoSet.handOver()
        #expect(handedOver.count == 2)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test(
        "A new set has room for the maximum of its limit",
        arguments: [(CameraFlowPhotoLimit.unlimited, Int?.none), (.single, 1), (.maximum(9), 9)]
    )
    func roomOfANewSet(limit: CameraFlowPhotoLimit, expectedRoom: Int?) {
        let photoSet = makeSet(limit: limit)
        #expect(photoSet.remainingCapacity == expectedRoom)
        photoSet.discard()
    }

    @Test("Removing a photo of a full set makes room again")
    func removeMakesRoom() throws {
        let photoSet = makeSet(limit: .single)
        try photoSet.add(FlowTestSupport.makeCapture(in: files))
        #expect(photoSet.isFull)
        let photo = try #require(photoSet.photos.first)
        photoSet.remove(photo)
        #expect(photoSet.isFull == false)
        #expect(photoSet.captureRefusal(photosInFlight: 0) == nil)
        photoSet.discard()
    }

    @Test("The camera takes no photo while the set is full and says why")
    func cameraRespectsLimit() async throws {
        let service = RecordingCameraService()
        var handedOver: [CameraFlowPhoto] = []
        let photoSet = makeSet(limit: .maximum(2)) { handedOver += $0 }
        let camera = makeCaptureModel(service: service, files: files, admission: photoSet, onCapture: photoSet.add)
        await camera.start()
        for _ in 0..<3 {
            await camera.capture()
        }
        #expect(photoSet.count == 2)
        #expect(camera.shutter.captureCount == 2)
        #expect(camera.notice.map(CameraNoticeText(.system).message) == "Limit of 2 photos reached")
        await photoSet.handOver()
        try FlowTestSupport.discardFiles(of: handedOver)
    }
}
