//
//  ReviewImageModelTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

/// The photos are 40 x 30 library photos, whose thumbnails have that size too, so a picture 20 wide is one that
/// was decoded for a screen of 20 pixels.
@MainActor
@Suite("Review images", .temporaryDirectory, .timeLimit(.minutes(1)))
struct ReviewImageModelTests {
    let harness = FlowHarness()
    let images: ReviewImageModel

    init() {
        images = ReviewImageModel(renderer: harness.renderer)
    }

    private static let screenPixelSize = 20

    private func makePhotos(_ count: Int) async throws -> [FlowPhoto] {
        let flow = harness.makeFlow()
        for _ in 0..<count {
            try await harness.importLibraryPhoto(into: flow)
        }
        try #require(flow.photoSet.count == count, "The set took \(flow.photoSet.count) of \(count) photos")
        return flow.photoSet.photos
    }

    private func isDecodedForScreen(_ photo: FlowPhoto) -> Bool {
        images.image(of: photo).width == Self.screenPixelSize
    }

    @Test("A photo that was not prepared is shown with its thumbnail")
    func thumbnailStandsIn() async throws {
        let photos = try await makePhotos(1)
        let photo = try #require(photos.first)
        #expect(images.image(of: photo) === photo.thumbnail)
        try FlowTestSupport.discardFiles(of: [photo])
    }

    @Test("Prepared photos are decoded at the size of the screen")
    func prepare() async throws {
        let photos = try await makePhotos(2)
        await images.prepare(photos, maximumPixelSize: Self.screenPixelSize)
        #expect(photos.allSatisfy(isDecodedForScreen))
        #expect(images.image(of: photos[0]).height == 15)
        try FlowTestSupport.discardFiles(of: photos)
    }

    @Test("Preparing other photos drops the pictures of the ones left out and keeps the ones still wanted")
    func dropsTheRest() async throws {
        let photos = try await makePhotos(4)
        await images.prepare(Array(photos[0...2]), maximumPixelSize: Self.screenPixelSize)
        let kept = images.image(of: photos[2])
        await images.prepare(Array(photos[2...3]), maximumPixelSize: Self.screenPixelSize)
        #expect(images.image(of: photos[0]) === photos[0].thumbnail)
        #expect(images.image(of: photos[1]) === photos[1].thumbnail)
        #expect(images.image(of: photos[2]) === kept)
        #expect(isDecodedForScreen(photos[3]))
        try FlowTestSupport.discardFiles(of: photos)
    }

    @Test("A page that grows, as an iPad window can, gets its photos decoded again for the larger size")
    func preparedForALargerPage() async throws {
        let photos = try await makePhotos(2)
        await images.prepare(photos, maximumPixelSize: Self.screenPixelSize)
        await images.prepare(photos, maximumPixelSize: 30)
        #expect(photos.allSatisfy { images.image(of: $0).width == 30 })
        try FlowTestSupport.discardFiles(of: photos)
    }

    @Test("A photo whose file cannot be decoded keeps its thumbnail")
    func undecodableFile() async throws {
        let capture = try FlowTestSupport.makeCapture(in: harness.files)
        let photo = FlowPhoto(capture: capture)
        await images.prepare([photo], maximumPixelSize: Self.screenPixelSize)
        #expect(images.image(of: photo) === photo.thumbnail)
        try FlowTestSupport.discardFiles(of: [photo])
    }

    @Test("A zoomed photo is decoded finer than the screen, until no photo is zoomed")
    func sharpen() async throws {
        let photos = try await makePhotos(2)
        await images.prepare(photos, maximumPixelSize: Self.screenPixelSize)
        await images.sharpen(photos[0])
        #expect(images.image(of: photos[0]).width == 40)
        #expect(isDecodedForScreen(photos[1]))
        await images.sharpen(nil)
        #expect(isDecodedForScreen(photos[0]))
        try FlowTestSupport.discardFiles(of: photos)
    }

    @Test("The finer picture goes when its photo is no longer prepared")
    func sharpenedPhotoLeftOut() async throws {
        let photos = try await makePhotos(2)
        await images.prepare(photos, maximumPixelSize: Self.screenPixelSize)
        await images.sharpen(photos[0])
        await images.prepare([photos[1]], maximumPixelSize: Self.screenPixelSize)
        #expect(images.image(of: photos[0]) === photos[0].thumbnail)
        try FlowTestSupport.discardFiles(of: photos)
    }

    // MARK: - Drawings

    /// The photo with a drawing on it, as the set would hold it. The drawings of the tests are made on a canvas
    /// of 400 x 300 points.
    private func drawn(_ photo: FlowPhoto, _ text: String = "ink") throws -> FlowPhoto {
        var drawnPhoto = photo
        drawnPhoto.drawing = try FlowTestSupport.makeDrawing(text)
        return drawnPhoto
    }

    @Test("A photo without a drawing has no picture of one, and none is rendered")
    func noDrawing() async throws {
        let photos = try await makePhotos(1)
        await images.prepare(photos, maximumPixelSize: Self.screenPixelSize)
        #expect(images.drawingImage(of: photos[0]) == nil)
        #expect(await harness.renderer.pictures.isEmpty)
        try FlowTestSupport.discardFiles(of: photos)
    }

    @Test("The drawing of a prepared photo is rendered with its canvas stretched to the size of the screen")
    func prepareDrawing() async throws {
        let photos = try await makePhotos(2)
        let photo = try drawn(photos[0])
        #expect(images.drawingImage(of: photo) == nil)
        await images.prepare([photo, photos[1]], maximumPixelSize: Self.screenPixelSize)
        let picture = try #require(images.drawingImage(of: photo))
        #expect(picture.width == 20)
        #expect(picture.height == 15)
        #expect(await harness.renderer.pictures.map(\.pixelSize) == [CGSize(width: 20, height: 15)])
        try FlowTestSupport.discardFiles(of: photos)
    }

    @Test("A picture that is there is not rendered again, and the picture of another drawing is")
    func rendersOnceForADrawing() async throws {
        let photos = try await makePhotos(1)
        let photo = try drawn(photos[0])
        await images.prepare([photo], maximumPixelSize: Self.screenPixelSize)
        let first = try #require(images.drawingImage(of: photo))
        await images.prepare([photo], maximumPixelSize: Self.screenPixelSize)
        await images.renderDrawing(of: photo)
        #expect(images.drawingImage(of: photo) === first)
        #expect(await harness.renderer.pictures.count == 1)
        let redrawn = try drawn(photos[0], "more ink")
        #expect(images.drawingImage(of: redrawn) == nil)
        await images.renderDrawing(of: redrawn)
        #expect(images.drawingImage(of: redrawn) != nil)
        #expect(images.drawingImage(of: photo) == nil)
        #expect(await harness.renderer.pictures.map(\.drawing) == [photo.drawing, redrawn.drawing])
        try FlowTestSupport.discardFiles(of: photos)
    }

    @Test("The picture goes when the drawing is taken off its photo, and when its photo is no longer prepared")
    func dropsDrawing() async throws {
        let photos = try await makePhotos(2)
        let first = try drawn(photos[0])
        let second = try drawn(photos[1])
        await images.prepare([first, second], maximumPixelSize: Self.screenPixelSize)
        await images.renderDrawing(of: photos[0])
        #expect(images.drawingImage(of: first) == nil)
        await images.prepare([first], maximumPixelSize: Self.screenPixelSize)
        #expect(images.drawingImage(of: second) == nil)
        #expect(images.drawingImage(of: first) != nil)
        try FlowTestSupport.discardFiles(of: photos)
    }

    @Test("Nothing is rendered before the review has said how large its screen is")
    func noSizeYet() async throws {
        let photos = try await makePhotos(1)
        let photo = try drawn(photos[0])
        await images.renderDrawing(of: photo)
        #expect(images.drawingImage(of: photo) == nil)
        #expect(await harness.renderer.pictures.isEmpty)
        try FlowTestSupport.discardFiles(of: photos)
    }

    @Test("The drawing of a zoomed photo is rendered as fine as the photo, until no photo is zoomed")
    func sharpenDrawing() async throws {
        let photos = try await makePhotos(1)
        let photo = try drawn(photos[0])
        await images.prepare([photo], maximumPixelSize: Self.screenPixelSize)
        await images.sharpen(photo)
        #expect(images.drawingImage(of: photo)?.width == ReviewImageModel.zoomedMaximumPixelSize)
        #expect(images.drawingImage(of: photo)?.height == ReviewImageModel.zoomedMaximumPixelSize * 3 / 4)
        await images.sharpen(nil)
        #expect(images.drawingImage(of: photo)?.width == 20)
        try FlowTestSupport.discardFiles(of: photos)
    }

    @Test("A zoom that another one overtook while its drawing rendered leaves the pictures of the other photo")
    func overtakenSharpen() async throws {
        let photos = try await makePhotos(2)
        let first = try drawn(photos[0], "first")
        let second = try drawn(photos[1], "second")
        await images.prepare([first, second], maximumPixelSize: Self.screenPixelSize)
        let gate = CallGate()
        await harness.renderer.holdPicture(number: 3, at: gate)
        let sharpening = Task { await images.sharpen(first) }
        await gate.arrival()
        await images.sharpen(second)
        await gate.open()
        await sharpening.value
        #expect(images.drawingImage(of: first)?.width == Self.screenPixelSize)
        #expect(images.drawingImage(of: second)?.width == ReviewImageModel.zoomedMaximumPixelSize)
        try FlowTestSupport.discardFiles(of: photos)
    }

    @Test("A drawing that renders for a preparation that was cancelled meanwhile is not kept")
    func cancelledPreparation() async throws {
        let photos = try await makePhotos(1)
        let photo = try drawn(photos[0])
        let gate = CallGate()
        await harness.renderer.holdPicture(number: 1, at: gate)
        let preparing = Task { await images.prepare([photo], maximumPixelSize: Self.screenPixelSize) }
        await gate.arrival()
        preparing.cancel()
        await gate.open()
        await preparing.value
        #expect(images.drawingImage(of: photo) == nil)
        try FlowTestSupport.discardFiles(of: photos)
    }

    @Test("A drawing that cannot be rendered leaves its photo without a picture of it")
    func unrenderableDrawing() async throws {
        let photos = try await makePhotos(1)
        let photo = try drawn(photos[0])
        await harness.renderer.failPictures()
        await images.prepare([photo], maximumPixelSize: Self.screenPixelSize)
        #expect(images.drawingImage(of: photo) == nil)
        #expect(isDecodedForScreen(photo))
        try FlowTestSupport.discardFiles(of: photos)
    }

    @Test("Releasing drops every picture, the zoomed ones and the drawings with them")
    func releaseAll() async throws {
        let photos = try await makePhotos(2)
        let photo = try drawn(photos[0])
        await images.prepare([photo, photos[1]], maximumPixelSize: Self.screenPixelSize)
        await images.sharpen(photo)
        try #require(images.drawingImage(of: photo) != nil)
        images.releaseAll()
        #expect(images.image(of: photo) === photo.thumbnail)
        #expect(images.image(of: photos[1]) === photos[1].thumbnail)
        #expect(images.drawingImage(of: photo) == nil)
        try FlowTestSupport.discardFiles(of: photos)
    }
}
