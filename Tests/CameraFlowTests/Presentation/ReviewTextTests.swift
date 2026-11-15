//
//  ReviewTextTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

@Suite("Review text and identifiers", .temporaryDirectory)
struct ReviewTextTests {
    let files = CaptureTestSupport.makeFileStore()

    /// The question about a photo of a source, with a drawing on it or without.
    private func confirmation(source: CameraFlowPhoto.Source, hasDrawing: Bool) throws -> DeleteConfirmation {
        let thumbnail = try FlowTestSupport.makeImage(width: 1, height: 1)
        var photo = FlowPhoto(
            id: UUID(),
            source: source,
            fileURL: files.directory.appendingPathComponent("photo.heic"),
            contentType: .heic,
            livePhotoMovieURL: nil,
            thumbnail: thumbnail,
            dualCameraCopy: nil
        )
        if hasDrawing {
            photo.drawing = try MarkupDrawing(engine: .paperKit, data: Data(), canvasSize: CGSize(width: 4, height: 3))
        }
        return DeleteConfirmation(photo: photo)
    }

    @Test("The counter and a tile say where a photo stands in the set")
    func position() {
        let position = PhotoPosition(number: 3, count: 5)
        #expect(ReviewText(.system).counter(position) == "3 of 5")
        #expect(ReviewText(.system).tile(position) == "Photo 3 of 5")
    }

    @Test("The controls of the review have their names")
    func controls() {
        #expect(ReviewText(.system).deletePhoto == "Delete photo")
        #expect(ReviewText(.system).markup == "Markup")
        #expect(ReviewText(.system).addFromLibrary == "Add from the photo library")
        #expect(ReviewText(.system).photo == "Photo")
        #expect(ReviewText(.system).currentPhoto == "Current photo")
        #expect(ReviewText(.system).withDrawing == "With a drawing")
    }

    @Test("The delete dialog asks about this photo")
    func deleteTitle() {
        #expect(ReviewText(.system).deleteTitle == "Delete this photo?")
    }

    @Test(
        "The delete dialog says whether the photo survives anywhere else, and that a drawing goes with it",
        arguments: [
            (CameraFlowPhoto.Source.camera, false, "This photo is not saved anywhere else."),
            (.photoLibrary, false, "It will stay in your photo library."),
            (.camera, true, "This photo is not saved anywhere else. The drawing will be gone too."),
            (.photoLibrary, true, "It will stay in your photo library. The drawing will be gone too.")
        ]
    )
    func deleteMessage(source: CameraFlowPhoto.Source, hasDrawing: Bool, message: String) throws {
        let confirmation = try confirmation(source: source, hasDrawing: hasDrawing)
        #expect(ReviewText(.system).deleteMessage(for: confirmation) == message)
    }

    @Test(
        "Chinese and Japanese join the two sentences without a space after the full stop",
        arguments: [
            ("ja", "この写真はほかの場所には保存されていません。描画も削除されます。"),
            ("zh-Hans", "这张照片没有保存在其他任何位置。涂鸦也将一并消失。"),
            ("zh-Hant", "這張照片沒有儲存在其他任何位置。塗鴉也會一併消失。")
        ]
    )
    func deleteMessageWithoutSpace(language: String, message: String) throws {
        let confirmation = try confirmation(source: .camera, hasDrawing: true)
        let localization = FlowLocalization(.specific(Locale.Language(identifier: language)))
        #expect(ReviewText(localization).deleteMessage(for: confirmation) == message)
    }

    @Test("The controls of the review have stable identifiers")
    func identifiers() {
        #expect(FlowIdentifier.reviewedPhoto == "flow.review.photo")
        #expect(FlowIdentifier.reviewDelete == "flow.review.delete")
        #expect(FlowIdentifier.reviewCounter == "flow.review.counter")
        #expect(FlowIdentifier.reviewMarkup == "flow.review.markup")
        #expect(FlowIdentifier.reviewAdd == "flow.review.add")
        #expect(FlowIdentifier.reviewTile(3) == "flow.review.tile.3")
    }
}
