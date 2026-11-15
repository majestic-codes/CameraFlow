//
//  PhotoSetHandOverObserverTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("A set tells the receiver of its controller of every hand-over", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoSetHandOverObserverTests {
    let files = CaptureTestSupport.makeFileStore()
    let outcome = FlowOutcome()
    let observer = RecordingHandOverObserver()

    /// A set the observer hears, with a Live Photo and a photo with a drawing, which the hand-over copies.
    private func makeSet(renderer: RecordingMarkupRenderer = RecordingMarkupRenderer()) throws -> PhotoSetModel {
        let photoSet = PhotoSetModel(limit: .unlimited, fileStore: files, renderer: renderer) { [outcome] in
            outcome.handedOver.append($0)
        }
        photoSet.handOverObserver = observer
        photoSet.add(try FlowTestSupport.makeCapture(in: files, withMovie: true))
        let drawn = try FlowTestSupport.makeCapture(in: files)
        photoSet.add(drawn)
        photoSet.setDrawing(try FlowTestSupport.makeDrawing(), ofPhoto: drawn.id)
        return photoSet
    }

    @Test("A hand-over is told as it begins and as it ends, and the set asks right before it hands its photos over")
    func handedOver() async throws {
        let photoSet = try makeSet()
        await photoSet.handOver()
        #expect(observer.events == [.began, .asked, .ended])
        let handedOver = try #require(outcome.handedOver.first)
        #expect(handedOver.count == 2)
        #expect(handedOver.flatMap(\.fileURLs).allSatisfy(FlowTestSupport.fileExists))
        #expect(try FlowTestSupport.isEntered(files.directory) == false)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A hand-over that leaves the set open, for a failed copy, is told as it begins and ends and asks nothing")
    func leftOpen() async throws {
        let renderer = RecordingMarkupRenderer()
        await renderer.failCopy(number: 1)
        let photoSet = try makeSet(renderer: renderer)
        await photoSet.handOver()
        #expect(observer.events == [.began, .ended])
        #expect(photoSet.notice == .copyFailed)
        #expect(photoSet.hasEnded == false)
        #expect(outcome.handedOver.isEmpty)
        photoSet.discard()
    }

    @Test("A set that reaches nobody is deleted with its directory instead of handed over, and the observer hears it")
    func reachesNobody() async throws {
        observer.isReceiving = false
        let photoSet = try makeSet()
        let photos = photoSet.photos
        await photoSet.handOver()
        #expect(observer.events == [.began, .asked, .deleted, .ended])
        #expect(outcome.handedOver.isEmpty)
        #expect(photoSet.hasEnded)
        #expect(photoSet.photos.isEmpty)
        expectDeleted(photos)
        #expect(FlowTestSupport.fileExists(files.directory) == false)
        #expect(try FlowTestSupport.isEntered(files.directory) == false)
    }
}
