//
//  PhotoReviewModelTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("Photo review", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoReviewModelTests {
    let harness = FlowHarness()

    // MARK: - The current photo

    @Test("A review that has not opened shows no photo")
    func closedReview() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 2)
        #expect(flow.review.currentPhoto == nil)
        #expect(flow.review.currentPosition == nil)
        #expect(flow.review.nearbyPhotos.isEmpty)
        flow.photoSet.discard()
    }

    @Test("The review counts the current photo from one")
    func position() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 3)
        #expect(flow.review.currentPosition == PhotoPosition(number: 3, count: 3))
        flow.review.show(flow.photoSet.photos[0].id)
        #expect(flow.review.currentPosition == PhotoPosition(number: 1, count: 3))
        flow.photoSet.discard()
    }

    @Test("A tile or a swipe shows another photo of the set, and a photo that is not in the set is not shown")
    func show() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 3)
        let photos = flow.photoSet.photos
        flow.review.show(photos[1].id)
        #expect(flow.review.currentPhoto?.id == photos[1].id)
        flow.review.show(UUID())
        #expect(flow.review.currentPhoto?.id == photos[1].id)
        flow.photoSet.discard()
    }

    @Test(
        "The pages one swipe reaches are the current photo and the ones beside it",
        arguments: [(0, [0, 1]), (2, [1, 2, 3]), (4, [3, 4])]
    )
    func nearbyPhotos(currentIndex: Int, nearbyIndices: [Int]) async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 5)
        let photos = flow.photoSet.photos
        flow.review.show(photos[currentIndex].id)
        #expect(flow.review.nearbyPhotos.map(\.id) == nearbyIndices.map { photos[$0].id })
        flow.photoSet.discard()
    }

    @Test("The only photo of a set has no neighbours")
    func nearbyPhotosOfSinglePhoto() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 1)
        #expect(flow.review.nearbyPhotos.map(\.id) == flow.photoSet.photos.map(\.id))
        flow.photoSet.discard()
    }

    // MARK: - Photo library

    @Test("Picks added from the review go to the end of the set, and the review shows the last of them")
    func importFromReview() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 2)
        flow.review.show(flow.photoSet.photos[0].id)
        let data = try FlowTestSupport.makeJPEG()
        await flow.importPicks([FakeLibraryPick(data: data), FakeLibraryPick(data: data)])
        #expect(flow.photoSet.photos.map(\.source) == [.camera, .camera, .photoLibrary, .photoLibrary])
        #expect(flow.review.currentPosition == PhotoPosition(number: 4, count: 4))
        flow.photoSet.discard()
    }

    @Test("The review stays on its photo until every pick is in")
    func importInProgress() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 2)
        let shown = try #require(flow.review.currentPhoto)
        let gate = CallGate()
        let data = try FlowTestSupport.makeJPEG()
        let picks = [FakeLibraryPick(data: data), FakeLibraryPick(data: data, gate: gate)]
        let importing = Task { await flow.importPicks(picks) }
        await gate.arrival()
        #expect(flow.photoSet.count == 3)
        #expect(flow.review.currentPhoto?.id == shown.id)
        await gate.open()
        await importing.value
        #expect(flow.review.currentPosition == PhotoPosition(number: 4, count: 4))
        flow.photoSet.discard()
    }

    @Test("Picks that could not be loaded leave the review where it is")
    func failedImport() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 2)
        let first = flow.photoSet.photos[0]
        flow.review.show(first.id)
        await flow.importPicks([FakeLibraryPick(data: nil)])
        #expect(flow.review.currentPhoto?.id == first.id)
        flow.photoSet.discard()
    }

    @Test("The \"+\" of the review opens the library while the set has room, and a delete makes room again")
    func addFromReview() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 2, limit: .maximum(2))
        flow.showReview()
        #expect(flow.canOpenLibrary == false)
        flow.review.requestDelete()
        let confirmation = try #require(flow.review.deleteConfirmation)
        await flow.deletePhoto(confirmedBy: confirmation)
        #expect(flow.canOpenLibrary)
        #expect(flow.librarySelectionLimit == 1)
        flow.openLibrary()
        #expect(flow.isLibraryPresented)
        flow.photoSet.discard()
    }

    // MARK: - Deleting

    @Test("The trash asks about the current photo, and a tap outside the dialog deletes nothing")
    func requestAndCancelDelete() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 2)
        let current = try #require(flow.review.currentPhoto)
        flow.review.requestDelete()
        #expect(flow.review.deleteConfirmation == DeleteConfirmation(photo: current))
        flow.review.cancelDelete()
        #expect(flow.review.deleteConfirmation == nil)
        #expect(flow.photoSet.count == 2)
        flow.photoSet.discard()
    }

    @Test("The dialog knows where the photo came from", arguments: [CameraFlowPhoto.Source.camera, .photoLibrary])
    func confirmationSource(source: CameraFlowPhoto.Source) async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 1)
        if source == .photoLibrary {
            try await harness.importLibraryPhoto(into: flow)
        }
        flow.showReview()
        flow.review.requestDelete()
        #expect(flow.review.deleteConfirmation?.source == source)
        #expect(flow.review.deleteConfirmation?.hasDrawing == false)
        flow.photoSet.discard()
    }

    @Test("The dialog knows that a drawing goes with the photo")
    func confirmationWithDrawing() throws {
        var photo = FlowPhoto(capture: try FlowTestSupport.makeCapture(in: harness.files))
        #expect(DeleteConfirmation(photo: photo).hasDrawing == false)
        photo.drawing = try MarkupDrawing(engine: .pencilKit, data: Data(), canvasSize: CGSize(width: 4, height: 3))
        #expect(DeleteConfirmation(photo: photo).hasDrawing)
        try FlowTestSupport.discardFiles(of: [photo])
    }

    @Test(
        "After a delete the review shows the photo that followed, or the one before it after the last photo",
        arguments: [(0, 1), (1, 2), (2, 1)]
    )
    func deleteShowsNeighbour(deletedIndex: Int, shownIndex: Int) async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 3)
        let photos = flow.photoSet.photos
        flow.review.show(photos[deletedIndex].id)
        flow.review.requestDelete()
        let confirmation = try #require(flow.review.deleteConfirmation)
        await flow.deletePhoto(confirmedBy: confirmation)
        #expect(flow.review.deleteConfirmation == nil)
        #expect(flow.review.currentPhoto?.id == photos[shownIndex].id)
        #expect(flow.photoSet.photos.map(\.id) == photos.map(\.id).filter { $0 != photos[deletedIndex].id })
        expectDeleted([photos[deletedIndex]])
        #expect(flow.mode == .review)
        flow.photoSet.discard()
    }

    @Test("Deleting the only photo returns to the camera and starts it again")
    func deleteOnlyPhoto() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 1)
        let photo = try #require(flow.review.currentPhoto)
        flow.review.requestDelete()
        let confirmation = try #require(flow.review.deleteConfirmation)
        let callsBefore = harness.service.calls.count
        await flow.deletePhoto(confirmedBy: confirmation)
        #expect(flow.photoSet.isEmpty)
        #expect(flow.review.currentPhoto == nil)
        #expect(flow.mode == .shooting)
        #expect(harness.service.calls.dropFirst(callsBefore).first == .start(.back))
        #expect(flow.canShowReview == false)
        expectDeleted([photo])
    }
}
