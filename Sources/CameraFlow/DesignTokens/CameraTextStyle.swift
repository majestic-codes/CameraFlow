//
//  CameraTextStyle.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// A text style of the camera chrome in numbers: the system font of a size and a weight, narrowed along its width
/// axis where one is given, and the stock space after every letter. `CameraTypography` sets the views in these
/// styles, and a text is measured in the same style, so a layout that makes room for a text makes it for the text
/// as it is set. The panel sizes are fitted to the text boxes of the stock screenshots.
struct CameraTextStyle: Equatable, Sendable {
    /// Weights on the scale of the system's font weights, the raw values of `UIFont.Weight`.
    enum Weight {
        static let light: CGFloat = -0.4
        static let regular: CGFloat = 0
        static let medium: CGFloat = 0.23
        static let semibold: CGFloat = 0.3
    }

    /// Width axis of the camera font in values, the same narrowing the zoom factors have.
    static let valueWidthAxis: CGFloat = 91
    /// Width axis of the small print in the Format sub-panel.
    static let captionWidthAxis: CGFloat = 92

    let size: CGFloat
    /// The weight on the scale of `Weight`.
    let weight: CGFloat
    /// The value on the width axis of the system font, nil for its own width.
    let widthAxis: CGFloat?
    /// The stock space after every letter, which `LetterTracking` gives the capitals of a language or not.
    let tracking: CGFloat
    /// Whether the digits share one width.
    let monospacedDigits: Bool

    init(
        size: CGFloat,
        weight: CGFloat = Weight.regular,
        widthAxis: CGFloat? = nil,
        tracking: CGFloat = 0,
        monospacedDigits: Bool = false
    ) {
        self.size = size
        self.weight = weight
        self.widthAxis = widthAxis
        self.tracking = tracking
        self.monospacedDigits = monospacedDigits
    }

    // MARK: - Zoom

    /// A zoom factor on a lens button and on the dial, a weight between the regular and the medium one, with the
    /// extra space the stock camera puts after every character.
    static let zoomFactor = Self(size: 14.25, weight: 0.12, widthAxis: valueWidthAxis, tracking: 0.375)
    /// A focal length under a label of the dial.
    static let focalLength = Self(size: 10, widthAxis: captionWidthAxis)

    // MARK: - Viewfinder

    /// The self-timer countdown. None of it was measured on the stock camera.
    static let countdown = Self(size: 120, weight: Weight.light, monospacedDigits: true)
    /// The notice capsule. None of it was measured on the stock camera.
    static let notice = Self(size: 14, weight: Weight.medium)

    // MARK: - Top bar

    /// A value written in the top bar instead of a glyph, such as "RAW" or "+0.7": the stock bar writes "HDR" so,
    /// capitals 10 pt high and "HDR" 26.3 pt wide, measured on the stock camera of iOS 27.
    static let topBarValue = Self(size: 14, weight: Weight.medium, widthAxis: valueWidthAxis)

    // MARK: - Control panel

    /// Tile labels such as "FLASH": capitals 10.67 pt high, "FLASH" 44 pt wide.
    static let tileLabel = Self(size: 13.6, tracking: 0.52)
    /// The upper line of the Format tile, "HEIF": capitals 13.33 pt high.
    static let formatTileFormat = Self(size: 19, widthAxis: valueWidthAxis)
    /// The lower line of the Format tile, the megapixel count such as "12": digits 10.33 pt high.
    static let formatTileMegapixels = Self(size: 14.5, widthAxis: valueWidthAxis)
    /// A value written on a tile instead of a glyph, such as a set exposure bias.
    static let tileValue = Self(size: 19, widthAxis: valueWidthAxis)

    // MARK: - Sub-panel

    /// Sub-panel title such as "FLASH": capitals 9.33 pt high, "TIMER" 40.33 pt wide.
    static let subPanelTitle = Self(size: 13.2, tracking: 0.5)
    /// The current value in the sub-panel, such as "Off" or "0.0": about 36 pt wide and 22 pt high.
    static let subPanelValue = Self(size: 29.5, widthAxis: valueWidthAxis)

    // MARK: - Format rows

    /// Row labels of the Format sub-panel, "FORMAT" and "QUALITY".
    static let formatRowLabel = Self(size: 9.6, widthAxis: captionWidthAxis, tracking: 0.1)
    /// Options of the Format sub-panel, such as "HEIF" or "High", and the words of the Save sub-panel.
    static let formatOption = Self(size: 14, weight: Weight.semibold, widthAxis: valueWidthAxis)
    /// The footnote under the options of the Format and the Save sub-panels.
    static let formatFootnote = Self(size: 11.2, widthAxis: captionWidthAxis)

    // MARK: - Flow

    /// The labels of the mode switch, such as "CAMERA".
    static let modeLabel = Self(size: 15, weight: Weight.medium, tracking: 0.5)
    /// The count on the review segment.
    static let badgeCount = Self(size: 12, weight: Weight.semibold)
    /// The place of the current photo at the top of the review, such as "5 of 5".
    static let reviewCounter = Self(size: 17, weight: Weight.semibold, monospacedDigits: true)
    /// "Cancel" on the glass capsule of the drawing mode.
    static let markupCancel = Self(size: 16, weight: Weight.medium)
    /// "Done" on the accent capsule of the drawing mode.
    static let markupDone = Self(size: 16, weight: Weight.semibold)
}
