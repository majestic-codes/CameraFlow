//
//  FlowIdentifier.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// Stable accessibility identifiers of the flow's own controls. The camera's are in `CameraIdentifier`.
enum FlowIdentifier {
    static let exit = "flow.exit"
    static let accept = "flow.accept"
    static let library = "flow.library"

    // MARK: - Review

    /// The page of the current photo.
    static let reviewedPhoto = "flow.review.photo"
    static let reviewDelete = "flow.review.delete"
    /// The place of the current photo in the set.
    static let reviewCounter = "flow.review.counter"
    static let reviewMarkup = "flow.review.markup"
    /// The "+" tile at the end of the strip.
    static let reviewAdd = "flow.review.add"

    /// The tile of a photo in the strip, by the number of the photo in the set, counted from one.
    static func reviewTile(_ number: Int) -> String {
        "flow.review.tile.\(number)"
    }

    // MARK: - Drawing

    static let markupCancel = "flow.markup.cancel"
    static let markupUndo = "flow.markup.undo"
    static let markupRedo = "flow.markup.redo"
    static let markupDone = "flow.markup.done"
    /// The canvas over the photo.
    static let markupCanvas = "flow.markup.canvas"

    // MARK: - Mode switch

    /// The count on the review segment.
    static let modeBadge = "flow.mode.badge"
    /// The spinner on the review segment while picks from the photo library load.
    static let modeImporting = "flow.mode.importing"

    static func mode(_ mode: CameraFlowMode) -> String {
        switch mode {
        case .shooting: "flow.mode.shooting"
        case .review: "flow.mode.review"
        }
    }
}
