//
//  ReviewText.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// What the review mode says: its controls, its counter, its strip and its delete dialog.
struct ReviewText {
    let localization: FlowLocalization

    init(_ localization: FlowLocalization) {
        self.localization = localization
    }

    // MARK: - Controls

    /// The trash and the destructive answer of its dialog.
    var deletePhoto: String {
        String(
            localized: "flow.review.delete",
            defaultValue: "Delete photo",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// The button that opens the drawing on the current photo, under the name the system gives that function.
    var markup: String {
        String(
            localized: "flow.review.markup",
            defaultValue: "Markup",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    var addFromLibrary: String {
        String(
            localized: "flow.review.add",
            defaultValue: "Add from the photo library",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    var photo: String {
        String(
            localized: "flow.review.photo",
            defaultValue: "Photo",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    // MARK: - Counter and strip

    /// What accessibility calls the counter at the top.
    var currentPhoto: String {
        String(
            localized: "flow.review.counter",
            defaultValue: "Current photo",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// The counter at the top, such as "5 of 5".
    func counter(_ position: PhotoPosition) -> String {
        String(
            localized: "flow.review.position",
            defaultValue: "\(position.number) of \(position.count)",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// What accessibility calls a tile of the strip, such as "Photo 3 of 5".
    func tile(_ position: PhotoPosition) -> String {
        String(
            localized: "flow.review.tile",
            defaultValue: "Photo \(position.number) of \(position.count)",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// The accessibility value of the tile of a photo with a drawing.
    var withDrawing: String {
        String(
            localized: "flow.review.tile.drawing",
            defaultValue: "With a drawing",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    // MARK: - Delete dialog

    var deleteTitle: String {
        String(
            localized: "flow.delete.title",
            defaultValue: "Delete this photo?",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// Whether the photo survives anywhere else, and that a drawing on it goes with it: one text for each case, which
    /// a language writes whole, with its own way of joining the sentences.
    func deleteMessage(for confirmation: DeleteConfirmation) -> String {
        switch (confirmation.source, confirmation.hasDrawing) {
        case (.camera, false):
            String(
                localized: "flow.delete.message.camera",
                defaultValue: "This photo is not saved anywhere else.",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case (.camera, true):
            String(
                localized: "flow.delete.message.camera.drawing",
                defaultValue: "This photo is not saved anywhere else. The drawing will be gone too.",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case (.photoLibrary, false):
            String(
                localized: "flow.delete.message.library",
                defaultValue: "It will stay in your photo library.",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case (.photoLibrary, true):
            String(
                localized: "flow.delete.message.library.drawing",
                defaultValue: "It will stay in your photo library. The drawing will be gone too.",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }
}
