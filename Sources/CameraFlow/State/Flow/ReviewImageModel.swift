//
//  ReviewImageModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Observation
import os

/// The pictures the review shows its photos with: the photo itself, and what is drawn on it as a picture to lay
/// over the photo.
///
/// A photo starts as its small thumbnail. The photos the review prepares, the current one and its neighbours, are
/// decoded at the size of the screen, so a swipe finds the next page ready, and one zoomed photo is decoded finer.
/// The drawing of a photo is rendered for the same sizes. Everything else is dropped, so a long set costs no more
/// memory than a short one.
@MainActor
@Observable
final class ReviewImageModel {
    private var screenImages: [UUID: CGImage] = [:]
    private var zoomedImage: ZoomedImage?
    private var screenDrawingImages: [UUID: DrawingImage] = [:]
    private var zoomedDrawingImage: DrawingImage?
    /// The long side the pictures for the screen were last prepared at, nil before the first time.
    private var screenMaximumPixelSize: Int?

    @ObservationIgnored private let renderer: any MarkupRenderer

    private struct ZoomedImage {
        let photoIdentifier: UUID
        let image: CGImage
    }

    /// The picture of a drawing of a photo, and the drawing it shows: a picture of another drawing is out of date.
    private struct DrawingImage {
        let photoIdentifier: UUID
        let drawingIdentifier: UUID
        let image: CGImage
    }

    /// The long side of the pictures of a zoomed photo, in pixels: 50 MB of pixels at the most for a 4:3 photo,
    /// and as much again for its drawing.
    static let zoomedMaximumPixelSize = 4096

    private static let logger = Logger.camera("ReviewImageModel")

    init(renderer: any MarkupRenderer) {
        self.renderer = renderer
    }

    /// The best picture of a photo there is now.
    func image(of photo: FlowPhoto) -> CGImage {
        if let zoomedImage, zoomedImage.photoIdentifier == photo.id {
            return zoomedImage.image
        }
        return screenImages[photo.id] ?? photo.thumbnail
    }

    /// The picture of a photo at least the size of the screen: the one prepared or zoomed, or else decoded now at
    /// the size the screen was prepared at, and kept. The thumbnail stands in for a photo that cannot be decoded,
    /// and before the review was ever laid out.
    func screenImage(of photo: FlowPhoto) async -> CGImage {
        if let zoomedImage, zoomedImage.photoIdentifier == photo.id {
            return zoomedImage.image
        }
        if let image = screenImages[photo.id] {
            return image
        }
        guard let screenMaximumPixelSize,
              let image = await decode(photo, maximumPixelSize: screenMaximumPixelSize) else {
            return photo.thumbnail
        }
        screenImages[photo.id] = image
        return image
    }

    /// The best picture there is now of what is drawn on a photo, nil for a photo without a drawing and until the
    /// drawing is rendered. It has the proportions of the photo and lies over the whole of it.
    func drawingImage(of photo: FlowPhoto) -> CGImage? {
        let candidates = [zoomedDrawingImage, screenDrawingImages[photo.id]].compactMap(\.self)
        let drawingIdentifier = photo.drawing?.identifier
        let current = candidates.first { $0.photoIdentifier == photo.id && $0.drawingIdentifier == drawingIdentifier }
        return current?.image
    }

    /// Drops the pictures of every other photo, decodes these photos at the size of the screen, at most
    /// `maximumPixelSize` on their long side, and renders their drawings for that size. Pictures made for another
    /// size are dropped too, and the thumbnails stand in until the new ones are ready. A cancelled call keeps what it
    /// has made so far.
    func prepare(_ photos: [FlowPhoto], maximumPixelSize: Int) async {
        if screenMaximumPixelSize != maximumPixelSize {
            screenImages = [:]
            screenDrawingImages = [:]
        }
        screenMaximumPixelSize = maximumPixelSize
        let preparedIdentifiers = Set(photos.map(\.id))
        screenImages = screenImages.filter { preparedIdentifiers.contains($0.key) }
        screenDrawingImages = screenDrawingImages.filter { preparedIdentifiers.contains($0.key) }
        if let zoomedImage, !preparedIdentifiers.contains(zoomedImage.photoIdentifier) {
            self.zoomedImage = nil
            zoomedDrawingImage = nil
        }
        await withTaskGroup(of: Void.self) { group in
            for photo in photos {
                group.addTask {
                    await self.decodeForScreen(photo, maximumPixelSize: maximumPixelSize)
                    await self.renderDrawing(of: photo)
                }
            }
        }
    }

    /// Drops every picture, for a review that is closed.
    func releaseAll() {
        screenImages = [:]
        screenDrawingImages = [:]
        zoomedImage = nil
        zoomedDrawingImage = nil
    }

    /// Decodes the photo that is zoomed finer than the screen and renders its drawing as fine, or drops those
    /// pictures when no photo is zoomed.
    func sharpen(_ photo: FlowPhoto?) async {
        guard let photo else {
            zoomedImage = nil
            zoomedDrawingImage = nil
            return
        }
        guard zoomedImage?.photoIdentifier != photo.id else { return }
        zoomedImage = nil
        zoomedDrawingImage = nil
        let image = await decode(photo, maximumPixelSize: Self.zoomedMaximumPixelSize)
        guard let image, !Task.isCancelled else { return }
        zoomedImage = ZoomedImage(photoIdentifier: photo.id, image: image)
        let drawingImage = await render(photo, maximumPixelSize: Self.zoomedMaximumPixelSize)
        guard let drawingImage, !Task.isCancelled, zoomedImage?.photoIdentifier == photo.id else { return }
        zoomedDrawingImage = drawingImage
    }

    /// Renders the drawing of a photo for the size of the screen, unless its picture is there already. A photo
    /// without a drawing loses the picture of the one it had.
    func renderDrawing(of photo: FlowPhoto) async {
        guard let drawing = photo.drawing else {
            screenDrawingImages[photo.id] = nil
            return
        }
        guard let screenMaximumPixelSize,
              screenDrawingImages[photo.id]?.drawingIdentifier != drawing.identifier else { return }
        let drawingImage = await render(photo, maximumPixelSize: screenMaximumPixelSize)
        guard let drawingImage, !Task.isCancelled else { return }
        screenDrawingImages[photo.id] = drawingImage
    }

    private func decodeForScreen(_ photo: FlowPhoto, maximumPixelSize: Int) async {
        guard screenImages[photo.id] == nil else { return }
        let image = await decode(photo, maximumPixelSize: maximumPixelSize)
        guard let image, !Task.isCancelled else { return }
        screenImages[photo.id] = image
    }

    /// The picture of a photo, nil for a file that cannot be decoded: its thumbnail stays on the screen.
    private func decode(_ photo: FlowPhoto, maximumPixelSize: Int) async -> CGImage? {
        do {
            return try await PhotoScreenImage.decode(url: photo.pictureURL, maximumPixelSize: maximumPixelSize)
        } catch {
            Self.logger.error("Cannot decode a photo for the review: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// The picture of the drawing of a photo with its canvas stretched to `maximumPixelSize` on its long side,
    /// nil for a photo without a drawing and for a drawing that cannot be rendered: the photo is shown without it.
    private func render(_ photo: FlowPhoto, maximumPixelSize: Int) async -> DrawingImage? {
        guard let drawing = photo.drawing else { return nil }
        let canvasSize = drawing.canvasSize
        let pixelsPerPoint = CGFloat(maximumPixelSize) / max(canvasSize.width, canvasSize.height)
        let pixelSize = CGSize(width: canvasSize.width * pixelsPerPoint, height: canvasSize.height * pixelsPerPoint)
        do {
            let image = try await renderer.image(of: drawing, pixelSize: pixelSize)
            return DrawingImage(photoIdentifier: photo.id, drawingIdentifier: drawing.identifier, image: image)
        } catch {
            Self.logger.error("Cannot render a drawing for the review: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
