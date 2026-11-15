//
//  PhotoSetHandOverTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("Photo set: the hand-over with the copies of the drawings", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoSetHandOverTests {

    private func copyNames(in harness: FlowHarness) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: harness.files.directory.path)
            .filter { $0.hasSuffix(".copy") }
    }

    // MARK: - Drawings

    @Test("A drawing is kept on its photo, replaced by the next one and taken off with nil")
    func setDrawing() async throws {
        let harness = FlowHarness()
        let flow = try await harness.makeStartedFlow(photoCount: 2)
        let photoSet = flow.photoSet
        let second = photoSet.photos[1]
        let first = try FlowTestSupport.makeDrawing("first")
        let next = try FlowTestSupport.makeDrawing("next")
        photoSet.setDrawing(first, ofPhoto: second.id)
        #expect(photoSet.photos.map(\.drawing) == [nil, first])
        photoSet.setDrawing(next, ofPhoto: second.id)
        #expect(photoSet.photos.map(\.drawing) == [nil, next])
        photoSet.setDrawing(first, ofPhoto: UUID())
        #expect(photoSet.photos.map(\.drawing) == [nil, next])
        photoSet.setDrawing(nil, ofPhoto: second.id)
        #expect(photoSet.photos.contains(where: \.hasDrawing) == false)
        photoSet.discard()
    }

    // MARK: - Hand-over

    @Test("Every photo with a drawing is handed over with its copy, written in the order of the set")
    func copies() async throws {
        let harness = FlowHarness()
        let flow = try await harness.makeStartedFlow(photoCount: 4, drawnIndices: [3, 1])
        let photos = flow.photoSet.photos
        await flow.accept()
        try #require(harness.outcome.handedOver.count == 1)
        let handedOver = harness.outcome.handedOver[0]
        try #require(handedOver.map(\.id) == photos.map(\.id))
        #expect(handedOver.map(\.original.url) == photos.map(\.fileURL))
        #expect(handedOver.map { $0.markedUp?.url != nil } == [false, true, false, true])
        #expect(await harness.renderer.copiedPhotoURLs == [photos[1].fileURL, photos[3].fileURL])
        for index in [1, 3] {
            let copyURL = try #require(handedOver[index].markedUp?.url)
            #expect(copyURL.deletingLastPathComponent() == harness.files.directory)
            #expect(handedOver[index].result.url == copyURL)
            #expect(handedOver[index].thumbnail.width == 40)
            #expect(handedOver[index].thumbnail.height == 30)
        }
        for index in [0, 2] {
            #expect(handedOver[index].result.url == handedOver[index].original.url)
            #expect(handedOver[index].thumbnail === photos[index].thumbnail)
        }
        #expect(flow.photoSet.hasEnded)
        #expect(flow.photoSet.isHandingOver == false)
        #expect(flow.photoSet.notice == nil)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A set without drawings is handed over without a copy")
    func noDrawings() async throws {
        let harness = FlowHarness()
        let flow = try await harness.makeStartedFlow(photoCount: 2, drawnIndices: [])
        await flow.accept()
        try #require(harness.outcome.handedOver.count == 1)
        #expect(harness.outcome.handedOver[0].allSatisfy { $0.markedUp?.url == nil })
        #expect(await harness.renderer.copiedPhotoURLs.isEmpty)
        try FlowTestSupport.discardFiles(of: harness.outcome.handedOver[0])
    }

    @Test("A copy that cannot be written stops the hand-over: the copies before it are deleted and the set stays")
    func failedCopy() async throws {
        let harness = FlowHarness()
        let flow = try await harness.makeStartedFlow(photoCount: 3, drawnIndices: [0, 1, 2])
        let photos = flow.photoSet.photos
        await harness.renderer.failCopy(number: 2)
        await flow.accept()
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(await harness.renderer.copiedPhotoURLs == [photos[0].fileURL, photos[1].fileURL])
        #expect(try copyNames(in: harness).isEmpty)
        #expect(flow.photoSet.hasEnded == false)
        #expect(flow.photoSet.isHandingOver == false)
        #expect(flow.photoSet.notice == .copyFailed)
        #expect(FlowText(.system).notice(for: flow) == "The copy with the drawing could not be saved")
        #expect(flow.photoSet.photos.map(\.id) == photos.map(\.id))
        #expect(flow.photoSet.photos.map(\.hasDrawing) == [true, true, true])
        #expect(photos.allSatisfy { FlowTestSupport.fileExists($0.fileURL) })
        #expect(flow.canAccept)
        #expect(flow.camera.delivery.isClosed == false)
        #expect(harness.service.calls.last != .stop)
        flow.photoSet.discard()
    }

    @Test("The check mark tried again after a failure hands the set over, and the notice is gone")
    func retry() async throws {
        let harness = FlowHarness()
        let flow = try await harness.makeStartedFlow(photoCount: 2, drawnIndices: [0, 1])
        await harness.renderer.failCopy(number: 2)
        await flow.accept()
        await flow.accept()
        try #require(harness.outcome.handedOver.count == 1)
        let handedOver = harness.outcome.handedOver[0]
        #expect(handedOver.allSatisfy { $0.markedUp?.url != nil })
        #expect(try copyNames(in: harness).count == 2)
        #expect(flow.photoSet.notice == nil)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("The set is handed over once, however often the check mark is pressed while the copies are written")
    func once() async throws {
        let gate = CallGate()
        let harness = FlowHarness(renderer: RecordingMarkupRenderer(gate: gate))
        let flow = try await harness.makeStartedFlow(photoCount: 2, drawnIndices: [0])
        let handingOver = Task { await flow.accept() }
        await gate.arrival()
        #expect(flow.isHandingOver)
        await flow.accept()
        await flow.photoSet.handOver()
        await gate.open()
        await handingOver.value
        await flow.accept()
        try #require(harness.outcome.handedOver.count == 1)
        #expect(await harness.renderer.copiedPhotoURLs.count == 1)
        #expect(try copyNames(in: harness).count == 1)
        try FlowTestSupport.discardFiles(of: harness.outcome.handedOver[0])
    }

    @Test("While the copies are written nothing else happens in the flow, and the set takes no change")
    func frozen() async throws {
        let gate = CallGate()
        let harness = FlowHarness(renderer: RecordingMarkupRenderer(gate: gate))
        let flow = try await harness.makeStartedFlow(photoCount: 2, drawnIndices: [1])
        flow.showReview()
        let photos = flow.photoSet.photos
        let handingOver = Task { await flow.accept() }
        await gate.arrival()
        #expect(flow.canShoot == false)
        #expect(flow.canShowReview == false)
        #expect(flow.canOpenLibrary == false)
        #expect(flow.canAccept == false)
        #expect(flow.acceptsCaptureButtons == false)
        flow.requestExit()
        await flow.startMarkup()
        await flow.showShooting()
        #expect(flow.exitConfirmation == nil)
        #expect(flow.markup.isOpen == false)
        #expect(flow.mode == .review)
        let late = try FlowTestSupport.makeCapture(in: harness.files)
        flow.photoSet.add(late)
        flow.photoSet.remove(photos[0])
        flow.photoSet.setDrawing(nil, ofPhoto: photos[1].id)
        await flow.photoSet.importPicks([FakeLibraryPick(data: try FlowTestSupport.makeJPEG())])
        expectDeleted([FlowPhoto(capture: late)])
        await gate.open()
        await handingOver.value
        try #require(harness.outcome.handedOver.count == 1)
        let handedOver = harness.outcome.handedOver[0]
        #expect(handedOver.map(\.id) == photos.map(\.id))
        #expect(handedOver.map { $0.markedUp?.url != nil } == [false, true])
        try FlowTestSupport.discardFiles(of: handedOver)
    }
}
