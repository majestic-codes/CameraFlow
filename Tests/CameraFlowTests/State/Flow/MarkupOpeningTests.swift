//
//  MarkupOpeningTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// The drawing mode as it opens and while it is open: over a picture as sharp as the screen, and on the photo it
/// was opened on whatever arrives meanwhile.
@MainActor
@Suite("The drawing mode as it opens", .temporaryDirectory, .timeLimit(.minutes(1)))
struct MarkupOpeningTests {
    let harness = FlowHarness()

    @Test("Markup tapped before the review decoded the photo opens over its picture at the size of the screen")
    func picture() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 1)
        let photo = try #require(flow.review.currentPhoto)
        // A screen size other than the thumbnail's tells the picture decoded for the screen from the thumbnail.
        let screenSize = 100
        await flow.review.images.prepare([], maximumPixelSize: screenSize)
        #expect(flow.review.images.image(of: photo) === photo.thumbnail)
        await flow.startMarkup()
        let opening = try #require(harness.canvasOpener.openings.first)
        #expect(max(opening.picture.width, opening.picture.height) == screenSize)
        #expect(flow.markup.session?.picture === opening.picture)
        #expect(flow.review.images.image(of: photo) === opening.picture)
        flow.photoSet.discard()
    }

    @Test("Markup before the review was ever laid out opens over the thumbnail")
    func thumbnail() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 1)
        let photo = try #require(flow.review.currentPhoto)
        await flow.startMarkup()
        #expect(harness.canvasOpener.openings.first?.picture === photo.thumbnail)
        flow.photoSet.discard()
    }

    @Test("Picks that arrive while a photo is drawn on leave the review and the canvas on that photo")
    func importDuringMarkup() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 2)
        let drawn = try #require(flow.review.currentPhoto)
        await flow.startMarkup()
        #expect(flow.markup.isOpen)
        let data = try FlowTestSupport.makeJPEG()
        await flow.importPicks([FakeLibraryPick(data: data)])
        #expect(flow.photoSet.count == 3)
        #expect(flow.review.currentPhoto?.id == drawn.id)
        #expect(flow.markup.session?.photoIdentifier == drawn.id)
        flow.photoSet.discard()
    }

    @Test("Picks that arrive while nothing is drawn on move the review to the last of them")
    func importWithoutMarkup() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 2)
        let data = try FlowTestSupport.makeJPEG()
        await flow.importPicks([FakeLibraryPick(data: data)])
        #expect(flow.review.currentPhoto?.id == flow.photoSet.photos.last?.id)
        flow.photoSet.discard()
    }
}
