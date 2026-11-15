//
//  CameraTypography.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// Fonts and tracking of the camera chrome, in the styles of `CameraTextStyle`: the system font narrowed to the
/// stock digit widths, with a slashed zero and an open four. The capitals take the stock tracking, except in a
/// language the stock camera sets without it (`LetterTracking`). A width function measures a text in the font its
/// view sets it in.
enum CameraTypography {
    // MARK: - Zoom

    static let zoomFactor = font(.zoomFactor)
    static let focalLength = font(.focalLength)
    /// Extra space the stock camera puts after every character of a zoom factor.
    static let zoomFactorKerning = CameraTextStyle.zoomFactor.tracking

    // MARK: - Viewfinder

    /// The message of a camera that does not run: 15 pt at the default text size, growing with Dynamic Type.
    static let message = Font.subheadline
    /// The button under the message of a camera that does not run.
    static let failureAction = Font.subheadline.weight(.semibold)
    static let countdown = font(.countdown)
    /// The size of a notice at the default text size, that of its style: it grows with Dynamic Type as the
    /// subheadline does.
    static let noticeSize = CameraTextStyle.notice.size

    /// A notice at its size for the text size in effect, in the plain system font, which Bold Text sets bolder.
    static func notice(size: CGFloat) -> Font {
        Font.system(size: size, weight: .medium)
    }

    // MARK: - Top bar

    static let topBarValue = font(.topBarValue)

    // MARK: - Control panel

    static let tileLabel = font(.tileLabel)
    static func tileLabelTracking(_ tracking: LetterTracking) -> CGFloat {
        tracking.amount(CameraTextStyle.tileLabel.tracking)
    }

    static let formatTileFormat = font(.formatTileFormat)
    static let formatTileMegapixels = font(.formatTileMegapixels)
    static let tileValue = font(.tileValue)

    // MARK: - Sub-panel

    static let subPanelTitle = font(.subPanelTitle)
    static func subPanelTitleTracking(_ tracking: LetterTracking) -> CGFloat {
        tracking.amount(CameraTextStyle.subPanelTitle.tracking)
    }

    static let subPanelValue = font(.subPanelValue)

    // MARK: - Format rows

    static let formatRowLabel = font(.formatRowLabel)
    static func formatRowLabelTracking(_ tracking: LetterTracking) -> CGFloat {
        tracking.amount(CameraTextStyle.formatRowLabel.tracking)
    }

    static let formatOption = font(.formatOption)
    static let formatFootnote = font(.formatFootnote)

    /// The width of a row label of the Format sub-panel as it is set, its tracking included.
    static func formatRowLabelWidth(_ label: String, tracking: LetterTracking) -> CGFloat {
        CameraTextStyle.formatRowLabel.width(of: label, tracking: tracking)
    }

    /// The width of an option of the Format sub-panel as it is set.
    static func formatOptionWidth(_ option: String) -> CGFloat {
        CameraTextStyle.formatOption.width(of: option, letterSpacing: 0)
    }

    // MARK: - Flow

    static let modeLabel = font(.modeLabel)
    static func modeLabelTracking(_ tracking: LetterTracking) -> CGFloat {
        tracking.amount(CameraTextStyle.modeLabel.tracking)
    }

    static let badgeCount = font(.badgeCount)
    static let reviewCounter = font(.reviewCounter)
    static let markupCancel = font(.markupCancel)
    static let markupDone = font(.markupDone)

    /// The width of a label of the mode switch as it is set, its tracking included.
    static func modeLabelWidth(_ label: String, tracking: LetterTracking) -> CGFloat {
        CameraTextStyle.modeLabel.width(of: label, tracking: tracking)
    }

    /// The width of "Cancel" on its capsule as it is set.
    static func markupCancelWidth(_ label: String) -> CGFloat {
        CameraTextStyle.markupCancel.width(of: label, letterSpacing: 0)
    }

    /// The width of "Done" on its capsule as it is set.
    static func markupDoneWidth(_ label: String) -> CGFloat {
        CameraTextStyle.markupDone.width(of: label, letterSpacing: 0)
    }

    // MARK: - Building

    /// The font of a style, also of one a glyph computes for its text.
    static func font(_ style: CameraTextStyle) -> Font {
        Font(style.makeFont())
    }
}
#endif
