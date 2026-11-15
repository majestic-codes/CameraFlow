//
//  DualCameraCopyTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("Photo set: the copy with the front camera's circle", .temporaryDirectory, .timeLimit(.minutes(1)))
struct DualCameraCopyTests {
    let files = CaptureTestSupport.makeFileStore()
    let renderer = RecordingMarkupRenderer()
    let outcome = FlowOutcome()

    private func makeSet() -> PhotoSetModel {
        PhotoSetModel(limit: .unlimited, fileStore: files, renderer: renderer) { [outcome] in
            outcome.handedOver.append($0)
        }
    }

    @Test("The review and a drawing use the copy with the circle, and the thumbnail is the capture's")
    func picture() throws {
        let capture = try FlowTestSupport.makeCapture(in: files, withDualCameraCopy: true)
        let photo = FlowPhoto(capture: capture)
        let copyURL = try #require(capture.dualCameraCopy?.url)
        #expect(photo.pictureURL == copyURL)
        #expect(photo.fileURLs.contains(copyURL))
        #expect(photo.thumbnail === capture.thumbnail)
        let plain = FlowPhoto(capture: try FlowTestSupport.makeCapture(in: files))
        #expect(plain.pictureURL == plain.fileURL)
        try FileManager.default.removeItem(at: files.directory)
    }

    @Test("A photo with the circle is handed over with its copy as the edited copy, the original untouched")
    func handOver() async throws {
        let capture = try FlowTestSupport.makeCapture(in: files, withDualCameraCopy: true)
        let originalBytes = try Data(contentsOf: capture.fileURL)
        let photoSet = makeSet()
        photoSet.add(capture)
        await photoSet.handOver()
        let photo = try #require(outcome.handedOver.first?.first)
        #expect(photo.original.url == capture.fileURL)
        #expect(photo.markedUp?.url == capture.dualCameraCopy?.url)
        #expect(photo.result.url == capture.dualCameraCopy?.url)
        #expect(photo.thumbnail === capture.thumbnail)
        #expect(try Data(contentsOf: capture.fileURL) == originalBytes)
        #expect(await renderer.copiedPhotoURLs.isEmpty)
        try FileManager.default.removeItem(at: files.directory)
    }

    @Test("A drawing goes over the copy with the circle, and the copy with both replaces it")
    func drawingOverCircle() async throws {
        let capture = try FlowTestSupport.makeCapture(in: files, withDualCameraCopy: true)
        let circleCopy = try #require(capture.dualCameraCopy?.url)
        let originalBytes = try Data(contentsOf: capture.fileURL)
        let photoSet = makeSet()
        photoSet.add(capture)
        photoSet.setDrawing(try FlowTestSupport.makeDrawing("over the circle"), ofPhoto: capture.id)
        await photoSet.handOver()
        #expect(await renderer.copiedPhotoURLs == [circleCopy])
        let photo = try #require(outcome.handedOver.first?.first)
        let markedUp = try #require(photo.markedUp?.url)
        #expect(markedUp != circleCopy)
        #expect(FlowTestSupport.fileExists(markedUp))
        #expect(FlowTestSupport.fileExists(circleCopy) == false)
        #expect(photo.original.url == capture.fileURL)
        #expect(try Data(contentsOf: capture.fileURL) == originalBytes)
        try FileManager.default.removeItem(at: files.directory)
    }

    @Test("A drawing whose copy fails keeps the copy with the circle for the next try")
    func failedDrawingCopy() async throws {
        await renderer.failCopy(number: 1)
        let capture = try FlowTestSupport.makeCapture(in: files, withDualCameraCopy: true)
        let circleCopy = try #require(capture.dualCameraCopy?.url)
        let photoSet = makeSet()
        photoSet.add(capture)
        photoSet.setDrawing(try FlowTestSupport.makeDrawing("drawing"), ofPhoto: capture.id)
        await photoSet.handOver()
        #expect(outcome.handedOver.isEmpty)
        #expect(photoSet.notice == .copyFailed)
        #expect(FlowTestSupport.fileExists(circleCopy))
        photoSet.discard()
    }

    @Test("Removing a photo and discarding the set delete the copy with the circle too")
    func deletion() throws {
        let removed = try FlowTestSupport.makeCapture(in: files, withDualCameraCopy: true)
        let discarded = try FlowTestSupport.makeCapture(in: files, withDualCameraCopy: true)
        let photoSet = makeSet()
        photoSet.add(removed)
        photoSet.add(discarded)
        photoSet.remove(FlowPhoto(capture: removed))
        #expect(FlowTestSupport.fileExists(try #require(removed.dualCameraCopy?.url)) == false)
        #expect(FlowTestSupport.fileExists(try #require(discarded.dualCameraCopy?.url)))
        photoSet.discard()
        #expect(FlowTestSupport.fileExists(try #require(discarded.dualCameraCopy?.url)) == false)
        #expect(FlowTestSupport.fileExists(discarded.fileURL) == false)
    }
}
