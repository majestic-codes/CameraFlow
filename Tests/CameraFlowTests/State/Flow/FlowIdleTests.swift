//
//  FlowIdleTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

/// A renderer whose copy is a file that is no image.
private actor UnreadableCopyRenderer: MarkupRenderer {
    private(set) var copyURLs: [URL] = []

    func image(of drawing: MarkupDrawing, pixelSize: CGSize) throws -> CGImage {
        try FlowTestSupport.makeImage(width: 4, height: 3)
    }

    func writeCopy(
        of photoURL: URL,
        with drawing: MarkupDrawing,
        output: CameraFlowOutput,
        into directory: URL
    ) throws -> URL {
        let copyURL = directory.appendingPathComponent("unreadable-\(copyURLs.count + 1).copy")
        try Data("no pixels here".utf8).write(to: copyURL)
        copyURLs.append(copyURL)
        return copyURL
    }
}

/// What the flow does with a request it cannot act on: nothing, and nothing changes.
@MainActor
@Suite("The flow asked for what it cannot do now", .temporaryDirectory, .timeLimit(.minutes(1)))
struct FlowIdleTests {
    private let harness = FlowHarness()

    // MARK: - Drawing

    @Test("Without an open canvas Cancel, Discard, Done, undo and redo do nothing")
    func markupWithoutCanvas() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 1)
        let markup = flow.markup
        markup.cancel()
        #expect(markup.isDiscardConfirmationPresented == false)
        markup.discard()
        markup.undo()
        markup.redo()
        await markup.finish()
        #expect(markup.isOpen == false)
        #expect(markup.notice == nil)
        #expect(flow.photoSet.photos.map(\.hasDrawing) == [false])
        #expect(harness.canvasOpener.openings.isEmpty)
        flow.photoSet.discard()
    }

    @Test("The camera does not come back while a photo is drawn on")
    func shootingDuringMarkup() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 1)
        await flow.startMarkup()
        #expect(flow.markup.isOpen)
        let before = harness.service.calls.count
        harness.haptics.removeAll()
        await flow.select(.shooting)
        await flow.showShooting()
        #expect(flow.mode == .review)
        #expect(flow.markup.isOpen)
        #expect(harness.service.calls.count == before)
        #expect(harness.haptics.events.isEmpty)
        flow.photoSet.discard()
    }

    // MARK: - Review

    @Test("The trash of a review without a photo asks nothing")
    func deleteWithoutPhoto() {
        let flow = harness.makeFlow()
        flow.review.requestDelete()
        #expect(flow.review.deleteConfirmation == nil)
        #expect(flow.review.currentPosition == nil)
    }

    @Test("A photo confirmed for deletion after the review moved on goes, and the review stays on its photo")
    func deleteAfterMovingOn() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 3)
        let photos = flow.photoSet.photos
        flow.review.show(photos[0].id)
        flow.review.requestDelete()
        let confirmation = try #require(flow.review.deleteConfirmation)
        flow.review.show(photos[2].id)
        await flow.deletePhoto(confirmedBy: confirmation)
        #expect(flow.photoSet.photos.map(\.id) == [photos[1].id, photos[2].id])
        #expect(flow.review.currentPhotoIdentifier == photos[2].id)
        #expect(flow.review.deleteConfirmation == nil)
        #expect(FlowTestSupport.fileExists(photos[0].fileURL) == false)
        flow.photoSet.discard()
    }

    @Test("During the countdown of the self-timer the review, the check mark and the library wait for the photo")
    func countdown() async throws {
        var state = CameraFlowInitialState()
        state.timer = CameraFlowSetting(.threeSeconds)
        let flow = harness.makeFlow(initialState: state)
        await flow.camera.start()
        try await harness.importLibraryPhoto(into: flow)
        #expect(flow.canShowReview)
        let shot = Task { await flow.camera.capture() }
        await harness.clock.waitForSleepers()
        #expect(flow.canShowReview == false)
        #expect(flow.canAccept == false)
        #expect(flow.canOpenLibrary == false)
        await flow.camera.capture()
        await shot.value
        #expect(flow.canShowReview)
        #expect(flow.canAccept)
        #expect(flow.canOpenLibrary)
        flow.photoSet.discard()
    }

    @Test("A confirmation for a photo that is already gone deletes nothing")
    func deleteTwice() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 2)
        let photos = flow.photoSet.photos
        flow.review.requestDelete()
        let confirmation = try #require(flow.review.deleteConfirmation)
        await flow.deletePhoto(confirmedBy: confirmation)
        await flow.deletePhoto(confirmedBy: confirmation)
        #expect(flow.photoSet.photos.map(\.id) == [photos[0].id])
        #expect(flow.review.currentPhotoIdentifier == photos[0].id)
        flow.photoSet.discard()
    }

    // MARK: - Review pictures

    @Test("A photo whose file is gone keeps its thumbnail when it is zoomed")
    func zoomedPhotoWithoutFile() async throws {
        let flow = harness.makeFlow()
        try await harness.importLibraryPhoto(into: flow)
        let photo = try #require(flow.photoSet.photos.first)
        try FileManager.default.removeItem(at: photo.fileURL)
        let images = ReviewImageModel(renderer: harness.renderer)
        await images.sharpen(photo)
        #expect(images.image(of: photo) === photo.thumbnail)
        flow.photoSet.discard()
    }

    @Test("A photo that is zoomed already is not decoded again")
    func zoomedTwice() async throws {
        let flow = harness.makeFlow()
        try await harness.importLibraryPhoto(into: flow)
        let photo = try #require(flow.photoSet.photos.first)
        let images = ReviewImageModel(renderer: harness.renderer)
        await images.sharpen(photo)
        let decoded = images.image(of: photo)
        #expect(decoded !== photo.thumbnail)
        await images.sharpen(photo)
        #expect(images.image(of: photo) === decoded)
        flow.photoSet.discard()
    }

    // MARK: - Hand-over

    @Test("A copy with a drawing that cannot be read back is deleted, and the set stays for another try")
    func unreadableCopy() async throws {
        let renderer = UnreadableCopyRenderer()
        var handedOver: [[CameraFlowPhoto]] = []
        let photoSet = PhotoSetModel(limit: .unlimited, fileStore: harness.files, renderer: renderer) {
            handedOver.append($0)
        }
        photoSet.add(try FlowTestSupport.makeCapture(in: harness.files))
        let photo = try #require(photoSet.photos.first)
        photoSet.setDrawing(try FlowTestSupport.makeDrawing(), ofPhoto: photo.id)
        await photoSet.handOver()
        let copyURL = try #require(await renderer.copyURLs.first)
        #expect(FlowTestSupport.fileExists(copyURL) == false)
        #expect(handedOver.isEmpty)
        #expect(photoSet.hasEnded == false)
        #expect(photoSet.notice == .copyFailed)
        #expect(FlowTestSupport.fileExists(photo.fileURL))
        photoSet.discard()
    }
}
