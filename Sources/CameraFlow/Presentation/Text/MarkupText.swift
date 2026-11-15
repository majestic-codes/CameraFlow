//
//  MarkupText.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// What the drawing mode says: its top bar, the dialog before a drawing is discarded and its notices.
struct MarkupText {
    let localization: FlowLocalization

    init(_ localization: FlowLocalization) {
        self.localization = localization
    }

    // MARK: - Top bar

    var cancel: String {
        String(
            localized: "flow.markup.cancel",
            defaultValue: "Cancel",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    var undo: String {
        String(
            localized: "flow.markup.undo",
            defaultValue: "Undo",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    var redo: String {
        String(
            localized: "flow.markup.redo",
            defaultValue: "Redo",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    var done: String {
        String(
            localized: "flow.markup.done",
            defaultValue: "Done",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// What accessibility calls the canvas over the photo.
    var canvas: String {
        String(
            localized: "flow.markup.canvas",
            defaultValue: "Drawing",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    // MARK: - Discard dialog

    var discardTitle: String {
        String(
            localized: "flow.markup.discard.title",
            defaultValue: "Discard the drawing?",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// The destructive answer of the dialog.
    var discardDrawing: String {
        String(
            localized: "flow.markup.discard.confirm",
            defaultValue: "Discard",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    // MARK: - Notices

    func message(for notice: MarkupNotice) -> String {
        switch notice {
        case .cannotOpen:
            String(
                localized: "flow.markup.notice.cannotOpen",
                defaultValue: "Markup could not be opened",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .cannotKeep:
            String(
                localized: "flow.markup.notice.cannotKeep",
                defaultValue: "The drawing could not be saved",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }
}
